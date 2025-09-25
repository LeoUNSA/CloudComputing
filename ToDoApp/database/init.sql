-- Crear la tabla de tareas
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertar algunas tareas de ejemplo
INSERT INTO tasks (title, description, completed) VALUES
('Bienvenido a tu gestor de tareas', 'Esta es una tarea de ejemplo. Puedes marcarla como completada o eliminarla.', false),
('Explorar la aplicación', 'Familiarízate con las funciones: crear, completar y eliminar tareas.', false),
('Personalizar tu experiencia', 'Agrega tus propias tareas y organiza tu trabajo diario.', false);

-- Función para actualizar timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para actualizar automáticamente updated_at
CREATE TRIGGER update_tasks_updated_at 
    BEFORE UPDATE ON tasks 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
