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
Pro bezpečné nasazení služby používáme manifesty s důrazem na bezpečnost podle NSA doporučení.

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
  replicas: 1
  selector:
    matchLabels:
      app: jmeno-aplikace
  template:
    metadata:
      labels:
        app: jmeno-aplikace
    spec:
      securityContext:
        runAsUser: 1000               # UID > 1000
        runAsGroup: 3000              # GID > 1000
        runAsNonRoot: true            # Povinné!
        allowPrivilegeEscalation: false
      containers:
        - name: jmeno-kontejneru
          image: jmeno-kontejneru:verze # NESMÍ být 'latest', musí mít konkrétní verzi
          imagePullPolicy: IfNotPresent
          securityContext:
            readOnlyRootFilesystem: true     # Povinné!
            capabilities:
              drop:
                - ALL                        # Snižujeme riziko eskalace
          ports:
            - containerPort: 8080            # HostPort NESMÍ být použit
          resources:
            requests:
              cpu: "100m"                    # MUSÍ být specifikováno
              memory: "128Mi"
            limits:
              cpu: "250m"                    # MUSÍ být specifikováno
              memory: "256Mi"
          volumeMounts:
            - mountPath: /data
              name: jmeno-aplikace
          env:
            - name: PROMENNA
              valueFrom:
                secretKeyRef:
                  name: jmeno-sekretu
                  key: klic
            - name: KONFIG
              valueFrom:
                configMapKeyRef:
                  name: jmeno-configmapy
                  key: nazev
          readinessProbe:
            exec:
              command: ["check.sh"]
            initialDelaySeconds: 5
            periodSeconds: 60
            timeoutSeconds: 10
            failureThreshold: 5
      volumes:
        - name: jmeno-aplikace
          persistentVolumeClaim:
            claimName: jmeno-volume-claim
      automountServiceAccountToken: false     # Povinné!
```

## Souhrn povinných pravidel (NSA):

| Pravidlo                       | Požadavek                                                              |
| ------------------------------ | ---------------------------------------------------------------------- |
| UID/GID                        | > 1000 (`runAsUser`, `runAsGroup`)                                     |
| `runAsNonRoot`                 | true                                                                   |
| `readOnlyRootFilesystem`       | true                                                                   |
| `allowPrivilegeEscalation`     | false                                                                  |
| `hostPath`                     | Zakázat                                                                |
| `hostPort`                     | Nesmí být použit                                                       |
| RBAC                           | Mít správně nastaveno – `create`, `exec` přístup zakázat podle potřeby |
| `automountServiceAccountToken` | false                                                                  |
| `capabilities`                 | drop: ALL                                                              |
| Požadavky CPU a paměti         | `requests` i `limits` MUSÍ být uvedeny                                 |
| Image tag                      | NESMÍ být `latest`, musí obsahovat verzi                               |

