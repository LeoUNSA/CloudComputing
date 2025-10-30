import React, { useState, useEffect } from 'react';
import axios from 'axios';

// Configurar la URL base para las peticiones
// En GCP/producción usa /api (proxy por nginx), en desarrollo usa localhost:30001
const API_URL = process.env.REACT_APP_API_URL || '/api';

function App() {
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [formData, setFormData] = useState({
    title: '',
    description: ''
  });

  // Cargar las tareas al iniciar
  useEffect(() => {
    fetchTasks();
  }, []);

  // Función para obtener todas las tareas
  const fetchTasks = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_URL}/tasks`);
      setTasks(response.data);
      setError('');
    } catch (err) {
      setError('Error al cargar las tareas. Verifique que el servidor esté funcionando.');
      console.error('Error fetching tasks:', err);
    } finally {
      setLoading(false);
    }
  };

  // Función para crear una nueva tarea
  const createTask = async (e) => {
    e.preventDefault();
    
    if (!formData.title.trim()) {
      setError('El título es requerido');
      return;
    }

    try {
      await axios.post(`${API_URL}/tasks`, formData);
      setFormData({ title: '', description: '' });
      setError('');
      fetchTasks(); // Recargar la lista
    } catch (err) {
      setError('Error al crear la tarea');
      console.error('Error creating task:', err);
    }
  };

  // Función para actualizar el estado de completado de una tarea
  const toggleTask = async (task) => {
    try {
      await axios.put(`${API_URL}/tasks/${task.id}`, {
        ...task,
        completed: !task.completed
      });
      fetchTasks(); // Recargar la lista
    } catch (err) {
      setError('Error al actualizar la tarea');
      console.error('Error updating task:', err);
    }
  };

  // Función para eliminar una tarea
  const deleteTask = async (id) => {
    if (window.confirm('¿Estás seguro de que quieres eliminar esta tarea?')) {
      try {
        await axios.delete(`${API_URL}/tasks/${id}`);
        fetchTasks(); // Recargar la lista
      } catch (err) {
        setError('Error al eliminar la tarea');
        console.error('Error deleting task:', err);
      }
    }
  };

  // Manejar cambios en el formulario
  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  return (
    <div className="container">
      <header className="header">
        <h1>📝 Gestor de Tareas</h1>
        <p>Organiza tus tareas de manera simple y eficiente</p>
      </header>

      {error && (
        <div className="error">
          {error}
        </div>
      )}

      {/* Formulario para crear nuevas tareas */}
      <form onSubmit={createTask} className="task-form">
        <h2>Nueva Tarea</h2>
        
        <div className="form-group">
          <label htmlFor="title">Título *</label>
          <input
            type="text"
            id="title"
            name="title"
            value={formData.title}
            onChange={handleInputChange}
            placeholder="Ingresa el título de la tarea"
            required
          />
        </div>

        <div className="form-group">
          <label htmlFor="description">Descripción</label>
          <textarea
            id="description"
            name="description"
            value={formData.description}
            onChange={handleInputChange}
            placeholder="Describe los detalles de la tarea (opcional)"
          />
        </div>

        <button type="submit" className="btn">
          ➕ Agregar Tarea
        </button>
      </form>

      {/* Lista de tareas */}
      <div className="tasks-list">
        <h2>Mis Tareas ({tasks.length})</h2>
        
        {loading ? (
          <div className="loading">
            Cargando tareas...
          </div>
        ) : tasks.length === 0 ? (
          <div className="no-tasks">
            No tienes tareas aún. ¡Crea tu primera tarea arriba!
          </div>
        ) : (
          tasks.map(task => (
            <div key={task.id} className="task-item">
              <div className="task-content">
                <input
                  type="checkbox"
                  className="checkbox"
                  checked={task.completed}
                  onChange={() => toggleTask(task)}
                />
                <h3 className={`task-title ${task.completed ? 'completed' : ''}`}>
                  {task.title}
                </h3>
                {task.description && (
                  <p className="task-description">{task.description}</p>
                )}
              </div>
              
              <div className="task-actions">
                <button
                  onClick={() => deleteTask(task.id)}
                  className="btn btn-danger btn-small"
                >
                  🗑️ Eliminar
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

export default App;
