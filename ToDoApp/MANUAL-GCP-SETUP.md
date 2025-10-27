# Comandos para Configurar GCP - Ejecutar UNO POR UNO

## Variables
```bash
export PROJECT_ID="todoapp-autoscaling-demo"
```

## 1. Crear Service Account
```bash
gcloud iam service-accounts create todoapp-deployer --display-name="TodoApp Deployer" --project=$PROJECT_ID
```

## 2. Asignar Roles (ejecutar uno por uno)
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:todoapp-deployer@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/container.admin"
```

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:todoapp-deployer@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/compute.admin"
```

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:todoapp-deployer@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/storage.admin"
```

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:todoapp-deployer@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/iam.serviceAccountUser"
```

## 3. Crear Credenciales
```bash
mkdir -p ~/.gcp
gcloud iam service-accounts keys create ~/.gcp/credentials.json --iam-account=todoapp-deployer@${PROJECT_ID}.iam.gserviceaccount.com --project=$PROJECT_ID
```

## 4. Habilitar APIs (ejecutar uno por uno)
```bash
gcloud services enable compute.googleapis.com --project=$PROJECT_ID
gcloud services enable container.googleapis.com --project=$PROJECT_ID
gcloud services enable containerregistry.googleapis.com --project=$PROJECT_ID
```

## 5. Configurar Variables de Entorno
```bash
export GCP_PROJECT_ID="todoapp-autoscaling-demo"
export GCP_CREDENTIALS_FILE="$HOME/.gcp/credentials.json"

# Guardar permanentemente
echo 'export GCP_PROJECT_ID="todoapp-autoscaling-demo"' >> ~/.bashrc
echo 'export GCP_CREDENTIALS_FILE="$HOME/.gcp/credentials.json"' >> ~/.bashrc
```

## 6. Verificar
```bash
bash /home/leo/CloudComputing/ToDoApp/check-ready.sh
```

## ✅ Una vez que todo esté configurado, proceder al deployment:
```bash
cd /home/leo/CloudComputing/ToDoApp
export GCP_PROJECT_ID="todoapp-autoscaling-demo"
export GCP_CREDENTIALS_FILE="$HOME/.gcp/credentials.json"
ansible-playbook ansible/main.yml
```
