# Vytváření manifestů

***

Pokud příkaz `kubectl get nodes` vrátí očekávaný počet nodes jak workers tak control-planes, které budou mít stav **Running** a **Ready**, nastává čas pro deployování služeb.

## Pod

***

Základní spustitelnou jednotkou pro službu je **Pod**. Můžete si ho představit jako *obal*, ve kterém běží jedna nebo více úzce spolupracujících kontejnerizovaných služeb.

Pro kontrolu podů v clusteru slouží
```bash
kubectl get pods
```

### Debugging

***

```bash
kubectl get pod <jméno podu>
```
> Vypíše to stejný co kubectl get pods ale pouze konkrétní pod
```bash
kubectl get pods -l app=<jméno aplikace>
```
> Vypíše všechny pody na kterých běží konrkténí služba

```bash
kubectl logs <jméno podu>
```
> Vypíše log podu

```bash
kubectl describe pod <jméno podu>
```
> Vypíše status podu

## Manifesty

***

Pod, a vlastně celou službu, definujeme pomocí tzv. **Manifestů**. Druhů manifestů je celá řada. V tomto dokumentu se zaměříme na ty, které byly při deployování UOIS využity.

### Deployment Manifest

***

Základním manifestem je tzv. **Deployment** manifest. Obsahuje veškeré informace potřebné pro běh služby. Obsahuje
- **Image**
- **Jméno**
- **Prt**
- **Environment variables**
- **Persistentní úložiště** (pokud je žádáno)

```app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jmeno-aplikace-deployment
spec:
  replicas: 1   // počet replik podu
  selector:
    matchLabels:
      app: jmeno-aplikace
  template:
    metadata:
      labels:
        app: jmeno-aplikace
    spec:
      containers:
        - name: jmeno-kontejneru
          image: jmeno-kontejneru:verze     // může být latest či číslo verze
          ports:
            - containerPort: cislo-portu    // číslo vnitřního portu
          volumeMounts:
            - mountPath: /cesta/kam/buoud/data/ukládána
              name: jmeno-aplikace
          env:
            - name: jmeno-promenne
              valueFrom:
                secretKeyRef:
                  name: jmeno-manifestu-typu-secret     // viz dál
                  key: jmeno-promenno
            - name: jmeno-promenne
              valueFrom:
                configMapKeyRef:
                  name: jmeno-manifestu-typu-configmap      // viz dál
                  key: jmeno-promenne
          readinessProbe:       // zjišťuje, jestli je aplikace ready
            exec:
              command: ["prikaz do aplikace"]
            initialDelaySeconds: 5
            periodSeconds: 60
            timeoutSeconds: 10
            failureThreshold: 5
      volumes:      // Persistentní storage
        - name: jmeno-aplikace
          persistentVolumeClaim:
            claimName: jmeno-volume-claim       // viz dál
```

### ConfigMap Manifest

***

Congifmap manifest je jeden ze dvou typů manifestu, kde jsou uloženy environmnet variables pro deployment. Configmap slouží k ukládání non-confidental dat.

```app-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: jmeno-aplikace-config
data:
  jmeno-promene: hodnota
  jmeno-promene: hodnota
```

Import v deploymentu viz Deployment
```app-deployment.yaml
.
.
.
- name: jmeno-promenne
              valueFrom:
                configMapKeyRef:
                  name: jmeno-manifestu-typu-configmap
                  key: jmeno-promenne
```

### Secret Manifest

***

Secret je druhý typ manifestu, který slouží k ukládání environment variables. Jak už název napovídá, na rozdíl od Configmap Secret ukládá důvěrná data jako hesla, jména, atd.

```app-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: jmeno-aplikace-secret
type: Opaque
data:
  jmeno-promene: hodnota-v-Base64
  jmeno-promene: hodnota-v-Base64

// alternativa - hodnoty nemusí být uloženy v Base64 kódování

apiVersion: v1
kind: Secret
metadata:
  name: jmeno-aplikace-secret
type: Opaque
stringData:
    jmeno-promene: hodnota
```

Import v deploymentu viz Deployment
```app-deployment.yaml
.
.
.
- name: jmeno-promenne
              valueFrom:
                secretKeyRef:
                  name: jmeno-manifestu-typu-secret
                  key: jmeno-promenno
```

### Service Deployment

***

Service deployment, jak už jméno napovídá, definuje službu. Uvnitř Deployment manifestu se definuje port. Jedná se ovšem o vnitřní který je dostupný pouze uvnitř podu. Aby byla služba dostupná i z jiných podů popř. úplně mimo K8s je nutný Service manifest.

```app-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: jmeno-aplikace    // Funguje de facto jako DNS. Když jiná aplikace odkazuje např na "gql-frontend:8000/gql" hledá to v services. Třeba dát pozor.
spec:
  type: NodePort    // Typ služby
  selector:
    app: jmeno-aplikace
  ports:
    - port: 8000    // Port, na kterém je služba dostupná uvnitř clusteru
      targetPort: 8000    //Vnitřní port podu
      nodePort: 32001   // Vnější port
```

## Persistentní úložiště

***

Kubernetes nebyly originálě dělány pro Persistentní úložiště, tedy takové, které se po smazání podu zachová. Existuje několik typů persistentního úložiště a její konfigurace. Uvedená dokumentace popisuje nastavení úložiště pro PostgreSQL v UOISu.

### Persistent Volume Manifest

***

Persistent Volume Manifest definuje objem dat, který si služba může nárokovat.

```app-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jmeno-aplikace-volume
  labels:
    type: local
    app: jmeno-aplikace
spec:
  storageClassName: manual
  capacity:
    storage: obejm-dat // např 70Gi
  accessModes:
    - ReadWriteMany   // Typ přístupu
  hostPath:
    path: /cesta/kde/budou/data
```

### Persistent Volume Claim Manifest

***

Persistent Volume Claim je typ Manifestu, kterým si aplikace zabere objem dat zpřístupněný v Persistent Volume Manifestu.

```app-claim.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jmeno-aplikace-volume-claim
  labels:
    app: jmeno-aplikace
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany   // Typ přístupu, musí být stejný jak v PV manifestu
  resources:
    requests:
      storage: 70Gi  // Požadovaný objem dat, stejný nebo menší než v PV
```