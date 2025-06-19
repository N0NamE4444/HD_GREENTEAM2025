# Terraform konfigurace pro nasazení na Azure
- tato konfigurace je vytvořena na základě docker-compose.hk2025.yml

## Soubory
- main.tf: hlavní soubor, který popisuje celou infrastrukturu
- terraform.tfvars: obsahuje nastavení proměnných
- systemdata.json: musí být přítomen - je nahrán do filesharu na azure

## Spuštění
- nainstalovat `terraform` a azure cli (příkaz `az`)
- spustit `terraform init` v adresáři terraform/
- zkontrolovat proměnné v terraform.tfvars
- spustit `terraform plan` a zkontrolvat výstup
- `terraform apply` pro nasazení
- pokud je vše ok, tak do konzole se vypíše FQDN, kde je frontend přístupný
- `terraform destroy` celou infrastrukturu zruší

## Výsledek
0. resource group a container app environment
- toto jsou struktury, které azure potřebuje pro provoz kontejnerů
1. kontejnery
-   `azurerm_container_app.gql_ug`
-   `azurerm_container_app.gql_externalids`
-   `azurerm_container_app.gql_events`
-   `azurerm_container_app.gql_facilities`
-   `azurerm_container_app.gql_granting`
-   `azurerm_container_app.gql_forms`
-   `azurerm_container_app.gql_projects`
-   `azurerm_container_app.gql_publications`
-   `azurerm_container_app.gql_lessons`
-   `azurerm_container_app.gql_surveys`
-   `azurerm_container_app.gql_admissions`
-   `azurerm_container_app.apollo`
-   `azurerm_container_app.frontend`
-   `azurerm_container_app.gql_analytics`
2. vytvoří databáze
- využívá služby Flexible server
3. file share
- obsahuje systemdata.json, který je potom mountovanej do kontejnerů

## Práce na další HD
- zprovoznit komunikaci mezi kontejnery
Pro správnou funkcionalitu je potřeba umožnit komunikaci mezi kontejnery. Momentálně se mi podařila jenom komunikace apollo -> gql-ug: `apollo# curl https://blablabla.blabla.gql-ug.azureblabla.bla`. Viz `main.tf:1077`.
- rozdělit main.tf do pod souborů
- otestovat škálování
- zjistit, kolik prostředků každá služba potřebuje


## Poznámky
- ne každý azure region podporuje Flexible server - je třeba si najít seznam regionů v dokumentaci azure
- přístup k logům kontejneru: Azure portal -> Resource group -> zvolit kontejner -> Pod aplikací zvolit Revisions and replicas -> vybrat revizi -> Logs -> Application logs
- přístup do kontejneru:
```sh
az containerapp exec \
    --name apollo \
    --resource-group rg-hk2025-app \ # nahradit rg z terraform.tfvars
    --command "/bin/sh"
```

---
Hacking Days 2025

Jakub Václav Flasar
