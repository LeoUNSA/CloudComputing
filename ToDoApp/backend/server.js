const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Configuración de la base de datos
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'database',
  database: process.env.DB_NAME || 'tasksdb',
  password: process.env.DB_PASSWORD || 'postgres',
  port: process.env.DB_PORT || 5432,
});

// Middleware
app.use(cors());
app.use(express.json());

// Verificar conexión a la base de datos
pool.connect()
  .then(() => console.log('✅ Conectado a PostgreSQL'))
  .catch(err => console.error('❌ Error conectando a PostgreSQL:', err));

// Rutas

// GET /tasks - Obtener todas las tareas
app.get('/tasks', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM tasks ORDER BY id DESC');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener las tareas' });
  }
});

// POST /tasks - Crear una nueva tarea
app.post('/tasks', async (req, res) => {
  try {
    const { title, description } = req.body;
    
    if (!title) {
      return res.status(400).json({ error: 'El título es requerido' });
    }

    const result = await pool.query(
      'INSERT INTO tasks (title, description, completed) VALUES ($1, $2, $3) RETURNING *',
      [title, description || '', false]
    );
    
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al crear la tarea' });
  }
});

// PUT /tasks/:id - Actualizar una tarea
app.put('/tasks/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, completed } = req.body;
    
    const result = await pool.query(
      'UPDATE tasks SET title = $1, description = $2, completed = $3 WHERE id = $4 RETURNING *',
      [title, description, completed, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Tarea no encontrada' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al actualizar la tarea' });
  }
});

// DELETE /tasks/:id - Eliminar una tarea
app.delete('/tasks/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await pool.query('DELETE FROM tasks WHERE id = $1 RETURNING *', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Tarea no encontrada' });
    }
    
    res.json({ message: 'Tarea eliminada correctamente' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al eliminar la tarea' });
  }
});

// Ruta de salud
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'API funcionando correctamente' });
});

// Ruta para generar carga CPU (para pruebas de autoscaling)
app.get('/stress', (req, res) => {
  const duration = parseInt(req.query.duration) || 30000; // 30 segundos por defecto
  const startTime = Date.now();
  
  console.log(`⚡ Iniciando stress test por ${duration}ms`);
  
  // Generar carga CPU intensiva
  while (Date.now() - startTime < duration) {
    Math.sqrt(Math.random() * 1000000);
    // Operaciones matemáticas intensivas
    for (let i = 0; i < 1000; i++) {
      Math.pow(Math.random(), Math.random());
    }
  }
  
  const elapsed = Date.now() - startTime;
  console.log(`✅ Stress test completado en ${elapsed}ms`);
  
  res.json({ 
    status: 'completed', 
    duration: elapsed,
    message: 'Stress test completado'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
});
