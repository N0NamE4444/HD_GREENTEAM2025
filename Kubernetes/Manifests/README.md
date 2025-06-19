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

### Deployment

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
  name: app-deployment
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
      volumes:
        - name: jmeno-aplikace
          persistentVolumeClaim:
            claimName: jmeno-volume-claim       // viz dál
```

