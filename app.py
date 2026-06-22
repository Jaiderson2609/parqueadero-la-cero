from flask import Flask, render_template, request, redirect, url_for, flash, session
import psycopg2
from psycopg2.extras import RealDictCursor
import hashlib

app = Flask(__name__)
app.secret_key = 'parqueadero_la_cero_secret_key'

DB_HOST = "localhost"
DB_NAME = "parqueadero_la_cero" 
DB_USER = "postgres"
DB_PASS = '12345'             

def obtener_conexion():
    """Retorna una conexión activa a la base de datos."""
    return psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS)

def encriptar_password(password):
    """Encripta la contraseña usando SHA-256."""
    return hashlib.sha256(password.encode('utf-8')).hexdigest()

# --- RUTAS DE AUTENTICACIÓN ---

@app.route('/')
def home():
    if 'usuario' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/registro', methods=['GET', 'POST'])
def registro():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        rol = request.form['rol']
        
        password_encriptada = encriptar_password(password)
        
        try:
            conn = obtener_conexion()
            cur = conn.cursor()
            # Insertamos el nuevo usuario
            cur.execute(
                "INSERT INTO usuarios (username, password_hash, rol) VALUES (%s, %s, %s)",
                (username, password_encriptada, rol)
            )
            conn.commit()
            cur.close()
            conn.close()
            flash('Usuario registrado exitosamente. Ahora puedes iniciar sesión.', 'success')
            return redirect(url_for('login'))
        except psycopg2.IntegrityError:
            flash('El nombre de usuario ya existe.', 'danger')
        except Exception as e:
            flash(f'Error al registrar: {str(e)}', 'danger')
            
    return render_template('registro.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        password_encriptada = encriptar_password(password)
        
        conn = obtener_conexion()
        # RealDictCursor nos permite acceder a las columnas por su nombre como un diccionario
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "SELECT * FROM usuarios WHERE username = %s AND password_hash = %s",
            (username, password_encriptada)
        )
        usuario = cur.fetchone()
        cur.close()
        conn.close()
        
        if usuario:
            # Guardamos el usuario y su rol en la sesión del navegador
            session['usuario'] = usuario['username']
            session['rol'] = usuario['rol']
            flash(f'¡Bienvenido {username}!', 'success')
            return redirect(url_for('dashboard'))
        else:
            flash('Credenciales incorrectas. Inténtalo de nuevo.', 'danger')
            
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    flash('Sesión cerrada correctamente.', 'info')
    return redirect(url_for('login'))


# --- CONTROL DE PANEL GENERAL ---

@app.route('/dashboard')
def dashboard():
    if 'usuario' not in session:
        flash('Por favor, inicia sesión primero.', 'warning')
        return redirect(url_for('login'))
    
    conn = obtener_conexion()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    # Obtener el estado del patio actual
    cur.execute("SELECT * FROM obtener_vehiculos_dentro();")
    vehiculos_dentro = cur.fetchall()
    
    # Cálculo condicional del recaudo para el Administrador
    recaudo_hoy = 0
    if session['rol'] == 'Administrador':
        # Se invoca la nueva función procedimental que filtra por el último corte a cero
        cur.execute("SELECT public.reporte_ingresos_desde_reinicio();")
        resultado = cur.fetchone()
        if resultado:
            recaudo_hoy = resultado['reporte_ingresos_desde_reinicio']
            
    cur.close()
    conn.close()
    
    return render_template('dashboard.html', vehiculos=vehiculos_dentro, recaudo=recaudo_hoy)


# --- OPERACIONES DE FLUJO DE PATIO ---

@app.route('/entrada', methods=['POST'])
def entrada():
    if 'usuario' not in session:
        return redirect(url_for('login'))
        
    # Bloquear al Administrador de tareas de patio
    if session.get('rol') == 'Administrador':
        flash('Acceso denegado: Los administradores no pueden registrar entradas.', 'danger')
        return redirect(url_for('dashboard'))
        
    placa = request.form['placa'].strip()
    tipo_vehiculo = request.form['tipo_vehiculo']
    
    if not placa:
        flash('La placa no puede estar vacía.', 'danger')
        return redirect(url_for('dashboard'))
        
    try:
        conn = obtener_conexion()
        cur = conn.cursor()
        cur.execute("SELECT registrar_entrada(%s, %s);", (placa, tipo_vehiculo))
        conn.commit()
        cur.close()
        conn.close()
        flash(f'Vehículo {placa.upper()} registrado exitosamente.', 'success')
    except Exception as e:
        error_msg = str(e).split('\n')[0]
        flash(f'Error: {error_msg}', 'danger')
        
    return redirect(url_for('dashboard'))


@app.route('/salida', methods=['POST'])
def salida():
    if 'usuario' not in session:
        return redirect(url_for('login'))
        
    # Bloquear al Administrador de tareas de patio
    if session.get('rol') == 'Administrador':
        flash('Acceso denegado: Los administradores no pueden registrar salidas.', 'danger')
        return redirect(url_for('dashboard'))
        
    placa = request.form['placa'].strip()
    
    try:
        conn = obtener_conexion()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT id_registro FROM registros_parqueo WHERE UPPER(placa) = UPPER(%s) AND estado = 'Activo';", (placa,))
        registro = cur.fetchone()
        
        if registro:
            cur.execute("SELECT calcular_tarifa(%s);", (registro['id_registro'],))
            total_pagar = cur.fetchone()['calcular_tarifa']
            
            cur.execute("SELECT registrar_salida(%s);", (placa,))
            conn.commit()
            
            flash(f'Salida procesada para {placa.upper()}. Total a cobrar: ${total_pagar:,.0f}', 'success')
        else:
            flash(f'El vehículo con placa {placa.upper()} no se encuentra activo en el parqueadero.', 'warning')
            
        cur.close()
        conn.close()
    except Exception as e:
        flash(f'Error al registrar salida: {str(e)}', 'danger')
        
    return redirect(url_for('dashboard'))


# --- LOGICA ADMINISTRATIVA AVANZADA ---

@app.route('/admin/reiniciar-recaudo', methods=['POST'])
def reiniciar_recaudo():
    if 'usuario' not in session or session.get('rol') != 'Administrador':
        flash('Acceso denegado.', 'danger')
        return redirect(url_for('login'))
    
    try:
        conn = obtener_conexion()
        cur = conn.cursor()
        # Insertamos la marca de tiempo actual en la tabla de control para fijar el punto cero
        cur.execute('INSERT INTO public.cierres_caja DEFAULT VALUES;')
        conn.commit()
        cur.close()
        conn.close()
        flash('El recaudo en pantalla se ha restablecido a cero con éxito.', 'success')
    except Exception as e:
        flash(f'Error al reiniciar el recaudo: {str(e)}', 'danger')
        
    return redirect(url_for('dashboard'))


if __name__ == '__main__':
    app.run(debug=True)
    