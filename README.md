Este Script para AzerothCore ofrece la posibilidad de vender objetos del juego a los jugadores, de manera muy controlada y configurable.

Primero se ejecuta el script SQL en la base de datos WORLD, esto agrega los NPCs con los IDs 60000 y 60001, llamados Michael Jackson y Configurador respectivamente.

El Script contiene una LISTA NEGRA de objetos prohibidos que el sistema ignorará por completo.

# ¿Por qué este script es eficiente?

# 1. Independencia arquitectónica: El sistema usa tablas dedicadas en la base de datos:<br>
<img width="251" height="129" alt="image" src="https://github.com/user-attachments/assets/e6de13f4-0122-46eb-9574-7b62294b70a2" /><br>
Esto no interfiere con las tablas item_template e item_template_locale, las cuales, están en constante uso por el Core.<br>

# 2. Configuración total

El NPC configurador muestra el siugiente menú:<br>
<img width="449" height="239" alt="image" src="https://github.com/user-attachments/assets/f32ecef6-9ea5-464d-bd8d-b2db096eff82" />

Lo que se puede configurar:<br>
<img width="444" height="560" alt="image" src="https://github.com/user-attachments/assets/d9362b5d-3269-497b-bee8-75a9d18b84af" /><br>
<img width="453" height="566" alt="image" src="https://github.com/user-attachments/assets/1e68268d-d3b8-4caf-8668-2f2846932bb8" /><br>

Cuando se termina de establecer la configuración deseada, se debe de clickear Aplicar Configuración:<br>
<img width="1179" height="265" alt="image" src="https://github.com/user-attachments/assets/aa84e479-87e1-4074-84eb-6a97656d511f" /><br>
<img width="445" height="51" alt="image" src="https://github.com/user-attachments/assets/87fe5168-acde-42c7-9742-355e4e04e38b" /><br>

Lo que sucede en este punto es que se ELIMINAN todos los registros de la tabla dedicada y se insertan nuevamente aplicando los filtros seleccionados.<br>
Esto ejecuta una consulta pesada en la base de datos, pero el sistema no requiere configuración constante.

# 3. Enfoque en experiencia de usuario
El sistema guarda compras frecuentes que el jugador realiza, esto agiliza enormemente la experiencia y evita que el jugador tenga que escribir constantemente un mismo nombre.

<img width="448" height="352" alt="image" src="https://github.com/user-attachments/assets/82bdfd84-96c7-4024-b7f3-4f7278eb546d" /><br>
<img width="450" height="352" alt="image" src="https://github.com/user-attachments/assets/cd08f5b7-1be1-45a6-9f13-0757c83e57c7" /><br>
En esta útima imagen, los objetos comprados frecuentemente se organizan por "veces comprados", los más frecuentes arriba.<br>
Se muestran un total de 15 objetos frecuentes.

# 4. Registro de compras
El sistema lleva un registro de lo que el jugador compró, cuánto compró, cuándo lo compró y cuánto dinero gastó, lo que transmite confianza y transparencia.<br>
Se muestra solo las últimas 20 compras, para no saturar los chats ni las vistas.<br>
Cabe añadir que los resultados se arreglan de manera cronológica, mostrando lo más reciente arriba.

<img width="643" height="184" alt="image" src="https://github.com/user-attachments/assets/cf4b93ae-7295-4cdb-8a8f-446280c2e510" />

# Cómo usar

<img width="1182" height="363" alt="image" src="https://github.com/user-attachments/assets/65c8e4fb-ef8c-4149-89d4-f74e0eff44b1" />

Se escribe nombre o parte del nombre del objeto en español, por ejemplo: 'paño de'

<img width="1184" height="353" alt="image" src="https://github.com/user-attachments/assets/34992ac8-0f79-4853-a817-f5b69bdab16f" />

Resultados:

<img width="481" height="868" alt="image" src="https://github.com/user-attachments/assets/cca4764d-9df0-4d09-b265-851de2678a2a" />

En los resultados impresos por el chat, el jugador puede clickear los links y verificar que el objeto que busca es el correcto.

Luego se ingresa la cantidad que desea:

<img width="428" height="90" alt="image" src="https://github.com/user-attachments/assets/bd95a3ef-023d-4398-9e28-08b37ddf4056" /><br>
<img width="405" height="142" alt="image" src="https://github.com/user-attachments/assets/56ed78e1-0c5b-49f4-90ea-ec745950b17c" /><br>

Se realiza la compra ofreciendo feedback constante del estado del sistema en el chat:<br>
<img width="587" height="107" alt="image" src="https://github.com/user-attachments/assets/9d66a3ff-5ec7-4aa5-b9c5-f6eb8212f114" />

