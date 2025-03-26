# Despliegue de Kubernetes con Minikube y KEDA

Este proyecto muestra el uso de KEDA para el autoescalado en Kubernetes utilizando Minikube.

![esquema](image/keda-architecture.png)


## Prerrequisitos

Asegúrete de tener instalados los siguientes requisitos:

- [Minikube](https://minikube.sigs.k8s.io/docs/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/)
- [Apache Benchmark (ab)](https://httpd.apache.org/docs/2.4/programs/ab.html) o una herramienta similar

## Uso del Makefile

El `Makefile` automatiza la creación y configuración del clúster de Minikube, el despliegue de Nginx y KEDA, y la simulación de tráfico. 

### 1. Crear el clúster de Minikube
```sh
make create-cluster
```
Esto inicia un clúster con los parámetros definidos en el `Makefile`.

### 2. Etiquetar los nodos
```sh
make label-nodes
```
Añade etiquetas y `taints` a los nodos para la afinidad con KEDA.

### 3. Desplegar Nginx
```sh
make deploy-nginx
```
Despliega un servidor Nginx en Kubernetes dentro del namespace definido.

### 4. Instalar KEDA
```sh
make deploy-keda
```
Instala KEDA en un namespace separado y lo configura con afinidad y toleraciones.

### 5. Crear el ScaledObject
```sh
make create-scaledobject
```
Despliega la configuración de autoescalado para Nginx.

### 6. Simular tráfico
```sh
make simulate-traffic
```
Ejecuta una carga de prueba para activar el autoescalado.

## Comprobaciones manuales

Estos comandos pueden ayudarte a verificar el estado del despliegue:

### Verificar nodos y etiquetas
```sh
kubectl get nodes --show-labels
```

### Verificar pods
```sh
kubectl get pods -A
```

### Verificar el escalado
```sh
kubectl get hpa -n my-app-ns
```

### Acceder a Nginx localmente
```sh
kubectl port-forward service/my-app 8080:80 -n my-app-ns
```
Luego abre en tu navegador: `http://localhost:8080`

### Verificar métricas en Prometheus
```sh
kubectl port-forward service/my-app 9113:9113 -n my-app-ns
```
Accede a las métricas en: `http://localhost:9113/metrics`

## Configuración del ScaledObject

El `ScaledObject` es el recurso que KEDA utiliza para definir las reglas de autoescalado. En este caso, el `ScaledObject` está configurado para escalar el despliegue `my-app` en función del uso de CPU:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: my-app-scaler
  namespace: my-app-ns
spec:
  scaleTargetRef:
    name: my-app
  minReplicaCount: 1
  maxReplicaCount: 5
  fallback:
    failureThreshold: 3
    replicas: 1
  advanced:
    restoreToOriginalReplicaCount: true
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 30
          policies:
            - type: Percent
              value: 100
              periodSeconds: 15
  triggers:
    - type: cpu
      metadata:
        type: Utilization
        value: "3"
```

Explicación de los parámetros:
- `scaleTargetRef`: Indica el despliegue (`my-app`) al que se aplicará el escalado.
- `minReplicaCount` y `maxReplicaCount`: Definen el número mínimo y máximo de réplicas.
- `fallback`: Especifica un estado seguro en caso de que KEDA falle (mantiene 1 réplica).
- `triggers`: Define la métrica para escalar (en este caso, el uso de CPU con umbral de 3%).

## Comprobación del autoescalado manual

Para verificar que KEDA está funcionando correctamente y está escalando los pods de Nginx en función de la carga, sigue estos pasos:

1. **Verifica el estado inicial de los pods:**
   ```sh
   kubectl get pods -n my-app-ns
   ```
   Inicialmente, debería haber solo una o pocas réplicas de Nginx en ejecución.

2. **Verifica que el Exporter de Prometheus está recolectando métricas:**
   ```sh
   kubectl port-forward service/my-app 9113:9113 -n my-app-ns
   ```
   Luego accede a `http://localhost:9113/metrics` y verifica que se están recolectando métricas de Nginx.

3. **Genera carga de tráfico para activar el escalado:**
   ```sh
   make simulate-traffic
   ```
   Esto simulará múltiples solicitudes hacia el servicio de Nginx.

4. **Observa cómo KEDA escala los pods:**
   ```sh
   kubectl get hpa -n my-app-ns
   ```
   Esto mostrará la métrica de escalado horizontal, indicando cuántas réplicas se están generando en respuesta a la carga.

5. **Verifica nuevamente los pods en ejecución:**
   ```sh
   kubectl get pods -n my-app-ns
   ```
   Deberías notar que el número de pods ha aumentado en función del tráfico generado.

6. **Detén la carga de tráfico y observa cómo los pods disminuyen:**
   Una vez que se detenga la carga, KEDA reducirá automáticamente el número de pods cuando ya no sean necesarios.
   ```sh
   kubectl get pods -n my-app-ns -w
   ```
   Observa cómo las réplicas disminuyen progresivamente hasta volver al estado inicial.

## Limpiar el entorno

Para eliminar el clúster de Minikube y limpiar los recursos creados, ejecuta:
```sh
make clean
```

## Notas
- Asegúrete de que Minikube tiene suficiente memoria y CPU asignada para manejar la carga.
- KEDA permite escalar basándose en métricas externas, como Prometheus o colas de mensajes.
- Puedes modificar los archivos YAML según sea necesario para personalizar el despliegue.

---

¡Listo! Ahora puedes probar KEDA con Minikube y ver el autoescalado en acción.

