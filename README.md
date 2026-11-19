# Grafana en Kubernetes con Deployment y ReplicaSet

Tarea individual de Procesos de Software (UDLA). Despliego Grafana 12 en Minikube con un **Deployment** de 3 réplicas, que crea y administra un **ReplicaSet**, y lo expongo con un **Service NodePort**.

## Estructura

```
k8s/
├── 00-namespace.yaml        # Namespace "monitoring"
├── 01-secret.yaml           # Usuario y contraseña admin de Grafana
├── 02-deployment.yaml       # Deployment: 3 réplicas, RollingUpdate, probes, recursos
├── 03-service.yaml          # Service NodePort 30300 -> puerto 3000 de Grafana
└── extra/
    └── replicaset-redis.yaml  # ReplicaSet aislado (sin Deployment) para comparar
```

## Requisitos

- Minikube y kubectl instalados

## Correr sin instalar nada (GitHub Codespaces)

En el repo: **Code → Codespaces → Create codespace on main**. El entorno ya trae Docker, Minikube y kubectl. Cuando cargue la terminal:

```bash
./demo.sh
```

Para las capturas del navegador, abre la pestaña **PORTS** y entra al puerto 3000.

## Demo automática

`./demo.sh` ejecuta todos los pasos de abajo en orden y se pausa en cada punto donde va una captura del informe.

```bash
chmod +x demo.sh
./demo.sh
```

## 1. Desplegar

```bash
minikube start
kubectl apply -f k8s/
kubectl get all -n monitoring
```

## 2. Ver la relación Deployment → ReplicaSet → Pods

```bash
kubectl get deploy,rs,pods -n monitoring -l app=grafana
kubectl describe deploy grafana -n monitoring
```

## 3. Acceder a Grafana

```bash
minikube service grafana -n monitoring --url
```

Abrir la URL en el navegador. Usuario `admin`, contraseña definida en `k8s/01-secret.yaml`.

## 4. Pruebas

**Autorreparación (ReplicaSet):** borro un Pod y el ReplicaSet crea otro.

```bash
kubectl delete pod -n monitoring $(kubectl get pod -n monitoring -l app=grafana -o jsonpath='{.items[0].metadata.name}')
kubectl get pods -n monitoring -l app=grafana -w
```

**Escalado:**

```bash
kubectl scale deploy grafana -n monitoring --replicas=5
kubectl get pods -n monitoring -l app=grafana
kubectl scale deploy grafana -n monitoring --replicas=3
```

**Rolling update (Deployment):** cambio la versión y se crea un ReplicaSet nuevo.

```bash
kubectl set image deploy/grafana grafana=grafana/grafana:12.1.0 -n monitoring
kubectl annotate deploy/grafana -n monitoring kubernetes.io/change-cause="Actualización a Grafana 12.1.0" --overwrite
kubectl rollout status deploy/grafana -n monitoring
kubectl get rs -n monitoring -l app=grafana
```

**Historial y rollback:**

```bash
kubectl rollout history deploy/grafana -n monitoring
kubectl rollout undo deploy/grafana -n monitoring
kubectl get rs -n monitoring -l app=grafana
```

**ReplicaSet sin Deployment (comparación):**

```bash
kubectl apply -f k8s/extra/replicaset-redis.yaml
kubectl get rs,pods -n monitoring -l app=redis-rs
```

## 5. Limpiar

```bash
kubectl delete namespace monitoring
minikube stop
```
