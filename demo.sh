#!/usr/bin/env bash
# Ejecuta la demo completa y se pausa en cada captura del informe.
# Uso: ./demo.sh   (requiere minikube y kubectl)
set -e
NS=monitoring

pausa() {
  echo
  echo "========================================================"
  echo "  📸 $1"
  echo "========================================================"
  read -rp "  Toma la captura y presiona Enter para continuar... "
  clear
}

clear
echo "▶ Iniciando Minikube"
minikube status >/dev/null 2>&1 || minikube start

echo "▶ kubectl apply -f k8s/"
kubectl apply -f k8s/00-namespace.yaml -f k8s/01-secret.yaml -f k8s/02-deployment.yaml -f k8s/03-service.yaml
pausa "Captura 2: recursos creados con kubectl apply"

echo "▶ Esperando a que los 3 Pods estén listos..."
kubectl rollout status deploy/grafana -n $NS
kubectl get deploy,rs,pods -n $NS -l app=grafana
pausa "Captura 3: Deployment 3/3, ReplicaSet y 3 Pods Running"

kubectl describe deploy grafana -n $NS | grep -E "Name:|Replicas:|StrategyType|RollingUpdateStrategy|Image:|NewReplicaSet"
pausa "Captura 4: estrategia RollingUpdate y NewReplicaSet"

POD=$(kubectl get pod -n $NS -l app=grafana -o jsonpath='{.items[0].metadata.name}')
echo "▶ Borrando el Pod $POD"
kubectl delete pod "$POD" -n $NS --wait=false
sleep 2
kubectl get pods -n $NS -l app=grafana
pausa "Captura 5: Pod borrado y Pod nuevo creado por el ReplicaSet"

echo "▶ Escalando a 5 réplicas"
kubectl scale deploy grafana -n $NS --replicas=5
kubectl rollout status deploy/grafana -n $NS
kubectl get pods -n $NS -l app=grafana
pausa "Captura 6: 5 Pods corriendo"
kubectl scale deploy grafana -n $NS --replicas=3
kubectl rollout status deploy/grafana -n $NS

echo "▶ Rolling update a Grafana 12.1.0"
kubectl set image deploy/grafana grafana=grafana/grafana:12.1.0 -n $NS
kubectl annotate deploy/grafana -n $NS kubernetes.io/change-cause="Actualización a Grafana 12.1.0" --overwrite
kubectl rollout status deploy/grafana -n $NS
kubectl get rs -n $NS -l app=grafana
pausa "Captura 7: ReplicaSet nuevo con 3 Pods y el anterior con 0"

echo "▶ Historial y rollback"
kubectl rollout history deploy/grafana -n $NS
kubectl rollout undo deploy/grafana -n $NS
kubectl rollout status deploy/grafana -n $NS
kubectl get rs -n $NS -l app=grafana
pausa "Captura 8: historial y ReplicaSet original otra vez con 3 Pods"

echo "▶ ReplicaSet sin Deployment (Redis)"
kubectl apply -f k8s/extra/replicaset-redis.yaml
kubectl wait --for=condition=Ready pod -l app=redis-rs -n $NS --timeout=120s
kubectl get rs,pods -n $NS -l app=redis-rs
pausa "Captura 9: ReplicaSet redis-rs con 2 Pods Running"

kubectl get svc -n $NS
URL=$(minikube service grafana -n $NS --url)
echo
echo "▶ URL del NodePort: $URL"
curl -s "$URL/api/health"; echo
pausa "Captura 10: Service grafana NodePort 80:30300 respondiendo"

echo "▶ Abriendo Grafana (usuario: admin, contraseña en k8s/01-secret.yaml)"
echo "  Toma las capturas 11 (login) y 12 (Grafana con sesión iniciada)."
echo "  Deja esta terminal abierta mientras usas el navegador; Ctrl+C para terminar."
if [ -n "$CODESPACES" ]; then
  echo "  En Codespaces: abre la pestaña PORTS y entra al puerto 3000 (Grafana)."
  kubectl port-forward svc/grafana -n $NS 3000:80
else
  minikube service grafana -n $NS
fi
