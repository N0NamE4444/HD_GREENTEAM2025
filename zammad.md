<h2>Dokončené úkoly</h2>  
<li>Nasazení Zammad pomocí Docker Compose.</li>
<li>Inicializace databáze a spuštění všech kontejnerů.</li>
<li>Zprovoznění přístupu přes webové rozhraní.</li>  
<li>Vytvoření administrátorského účtu.</li>  
<li>Základní konfigurace systému (role).</li>

<h2>Odkaz na Zammad repozitář</h2>
<p>https://github.com/zammad/zammad-docker-compose</p>

<h2>Nasazení s Docker-Compose</h2>
<h3>Clone the GitHub Repo:</h3>
<code>git clone https://github.com/zammad/zammad-docker-compose.git</code>
<h3>Spuštění:</h3>
<code>cd zammad-docker-compose</code>

<code>docker compose up -d</code>

<h2>Postup nastavení pracovní hierarchie</h2>
<h3>1. Vytvoření rolí </h3>
<li>Z administrátorksého účtu je třeba vytvořit role tak, aby odpovídali pravomoce uživatelů.</li>
<li>Např. správce skupiny, člen skupiny.</li>
<h3>2. Založení jednotlivých skupin</h3>
<li>Red team, Blue team...</li>
<h3>3. Správa organizací</h3>
<li>Slouží pro zjednodušené odesílání ticketů.</li>
<li>Název organizace shodný s názvem skupiny.</li>
<h3>4. Zadání jednotilvých uživatelů</h3>
<li>Zadání uživatelských informacích, nastevní role, zařazení do skupiny a organizace.</li>

<h2>Vytvoření ticketu</h2>
<h3>Povinné parametry:</h3>
<li>Název ticketu</li>
<li>Zákazník/Organizace</li>
<li>Text, vložený soubor</li>
<li>Stav ticketu</li>
<li>Priorita</li>
