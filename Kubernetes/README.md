# Kubernetes Dokumentace

***
Jako první je potřeba si uvědomit, co Kubernetes je. Hlavní funkce, což je i důvod proč K8s vzniklo, je tzv. **orchestrace** kontejnerů.

## Motivace

***

Předpokládám, že zkušenosti s Dockerem už máte, takže základní představu o jeho fungování a benefitech kontejnerizace máte. Teď si ale představte reálné nasazení nějakého systému, jako např. UOIS.

Při hostování na jednom stroji stačí Docker. Přes Dockerfile nebo Docker Compose nadefinuju porty, repliky, udělám pull a jedem. Časem ale může dojít k nutnosti zvýšení výkonu a high availibility (HA). To je možné udělat přidáním dalšího serveru. Znovu na něj nahrajete Docker, pullnete image a nastavit nějaký load balancing. No ale takových oddělených serverů můžou být desítky nebo i stovky. Kvůli necentralizované správě budete muset obejít každý server a ručně na něm udělat tížené změny. Docela nepraktické co? ;) A přesně tady vstupuje do hry Kubernetes. Vytvořením clusteru klidně o tísíci (worker) serverech můžeme přes jeden (control-plane) ovládat všechny ostatní. Respektive my control-planu řekneme "tady je image, chcu tolik replik a starej se" a on se stará. Kubernetes zajišťují, že náše žádané služby a jejich repliky vždy pojedou.

## Obsah

***

 - IP adresy nodes
 - Instalace
   - Control-plane node instalace
     - Instalace Containerd jako container runtime interface CRI

## IP adresy nodes:

***

| **k8s-cp1:** | **k8s-w1:** | **k8s-w2:** | **k8s-w3:** |
| ------------ | ----------- | ----------- | ----------- |
| `160.216.223.79` | `160.216.223.84` |   `160.216.223.85` | `160.215.223.97` |

***

## Instalace

***

### Úvodní set-up

***

Tato konfigurace je stejná pro všechny typy nodes v Kubernetes clusteru.

viz: [Instalace Kubeadm](https://v1-32.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)

```bash
sudo apt update && sudo apt upgrade
```

#### Instalace Containerd jako container runtime interface CRI

***

viz: [Instalace Containerd](https://v1-32.docs.kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd-systemd)

K8s samy o sobě neumí kontejnerizaci. K tomu slouží nějaký CRI. Na výběr je několik variant. Já zvolil Containerd.

>**POZOR:** Docker není CRI, NEBUDE FUNGOVAT!

Komplikovaná instalace - záleží na hodně věcech jako jestli na systému běží systemd a jaký cgroup driver využívá jestli v1 nebo v2. Od toho se odvíjí config. Na ubuntu serveru na Proxmoxu běží systemd a cgroup driver v2, config se tedy odvíjí podle toho. Pokud bude environment jiný, je potřeba config upravit viz dokumentace

```bash
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
```

##### Úprava config file

```bash
sudo vim /etc/containerd/config.toml
```
 - Ujistit se, že CRI plugin není disabled
 ```config.toml
 disabled_plugins = {}
 ```
 - Přepsat verzi sandbox_image
> **Poznámka:**
V pozdější fázi po inicializaci clusteru příkazem *kubeadm init* může dojít k chybové hlášce upozorňující, že kubeadm vyžaduje jinou verzi. Nejedná se o Error pouze o Warning.
 ```config.toml
 [plugins."io.containerd.grpc.v1.cri"]
    .
    .
    .
    sandbox_image = "registry.k8s.io/pause:3.10"
 ```
 - Přepsat SystemdCgroup
```config.toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    .
    .
    .
    SystemdCgroup = True
```
 - Uložit, zavřít
 - Restartovat containerd:
```bash
sudo systemctl restart containerd
```
- Kontrola
```bash
sudo systemctl status containerd
```
 - Containerd by měl být enabled a running bez žádného erroru

#### Vypnutí swapování:

***

Pro správnou funkci je nutné vypnout swapování
```bash
sudo swapoff -a
```
Swapoff je pouze do restartování, pro persistentní vypnutí je nutné vykomentovat poslední řádek v */etc/fstab*
```bash
vim /etc/fstab
```
```/etc/fstab
.
.
.
# swap.img    none     swap   Sw   0   0
```

#### Instalace Kubeadm, Kubelet a Kubectl:

***

> Poznámka: vždy při instalaci kopíruj příkazy z [oficiální stránky](https://v1-32.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#k8s-install-0). Tyto mohou být **outdated**!

```bash
sudo apt install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```


### Instalace Control-plane Node - Vytvoření clusteru

***

viz [Vytvoření clusteru](https://v1-32.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)

Každý node musí mít unikátní **Hostname**
```bash
sudo hostnamectl set-hostname <hostname>
```
Inicializace clusteru
```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --cri-socket unix:///run/containerd/containerd.sock
```
> *pod-network-cidr* nastaví adresní rozsah - kvůli použití Flannelu (další kroky) **NUTNÉ ZACHOVAT**

> *cri-socket* definuje socket, na kterém má Kubernetes hledat software pro kontejnerizaci

Po dokončení tohoto příkazu se objeví *kubeadm join command* který slouží k připojení nodu do clusteru

Vytvoření config file
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
Instalace Control network interface plugin - Flannel (může být i jiný), bez toho Kubernetes nejede. Pro bližší info GitHub:
```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```
Restart kubectl:
```bash
sudo service kubelet restart
```
Kontrola - k8s-cp1 Ready:
```bash
kubectl get node
```

### Instalace Worker node

***

Stejná jako doposud. Jediný rozdíl je, že místo *kubeadm init* se použije příkaz *kubeadm join* buď vygenerovaný po initu, nebo pomocí příkazu.

> **POZOR!** Token, který je součástí kubeadm join commandu, má životnost 24 hodin. Pak je třeba vygenerovat nový:

```bash
kubeadm token create --print-join-command
```

Kontrola na Control-plane node
```bash
kubectl get nodes
```
Woker node nemá assignutou roli - ničemu to nevadí, jedná se o kosmetický a informativní údaj.

Good practise je pod olabelovat pro větší přehlednost
```bash
kubectl label node k8s-w1 node-role.kubernetes.io/worker=""
```

#### *Known issues*, které nastaly při instalaci worker node:

***

Nebyl povolen IPv4 port fowarding
```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system
sysctl net.ipv4.ip_forward
```
Je nutné nainstalovat Flannel (příp. jiný CNI, v celém clusteru stejný) - na Woker nodes nefungoval, bylo nutné zapnout br_netfilter kernel modul:

```bash
sudo modprobe br_netfilter
echo 'br_netfilter' | sudo tee /etc/modules-load.d/k8s.conf
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
kubectl delete pod -n kube-flannel --all
```