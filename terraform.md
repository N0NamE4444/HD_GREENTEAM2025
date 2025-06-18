# Stav projektu UOIS Terraform
## Dokončené úkoly

- [x] Aktualizace infrastruktury - Přechod z deprecated PostgreSQL serveru na Flexible Server
- [x] Bezpečnost - Přesun hesel do .tfvars souborů
- [x] Azure autentizace - Nastaveno připojení přes az login

## Aktuálně nasazené komponenty

- Resource Group v West Europe
- 2x PostgreSQL Flexible Server (frontend + gql databáze)
- Container App Environment s monitoringem
- Frontend Container App (veřejně přístupný)
- Apollo Federation Gateway
- 10 GraphQL mikroslužeb
- Analytics služba

## Technické vylepšení

- Upgrade PostgreSQL z verze 11 na 13
- Přechod na moderní Azure Container Apps
- Konfigurace autoscalingu a health checků
- Správné síťové propojení služeb

## Zbývající úkoly
- Nasazení na Azure
