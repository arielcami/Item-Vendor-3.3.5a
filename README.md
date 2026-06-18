Este Script para AzerothCore ofrece la posibilidad de vender objetos del juego a los jugadores, de manera muy controlada y configurable.

Primero se ejecuta el script SQL en la base de datos WORLD, esto agrega los NPCs con los IDs 60000 y 60001, llamados Michael Jackson y Configurador respectivamente.

El Script contiene una LISTA NEGRA de objetos prohibidos que el sistema ignorará por completo.

# ¿Por qué este script es eficiente?

# 1. Independencia arquitectónica: El sistema usa tablas dedicadas en la base de datos:<br>
<img width="235" height="178" alt="image" src="https://github.com/user-attachments/assets/88bc99c2-0fc2-4bb7-a71e-fed1c095ae9c" /><br>
Esto no interfiere con las tablas item_template e item_template_locale, las cuales, están en constante uso por el Core.<br>

# 2. Enfoque en experiencia de usuario
El sistema guarda compras frecuentes que el jugador realiza, esto agiliza enormemente la experiencia y evita que el jugador tenga que escribir constantemente un mismo nombre.
Permite buscar objetos tanto por el nombre como el ID.

<img width="460" height="463" alt="image" src="https://github.com/user-attachments/assets/4f5d9ea8-85ab-4c7b-bb90-f16610962224" />

<img width="458" height="475" alt="image" src="https://github.com/user-attachments/assets/5f40454c-3e4d-477c-a7fd-29b4d8f2696b" /><br>
En esta útima imagen, los objetos comprados frecuentemente se organizan por "veces comprados", los más frecuentes arriba.<br>

# 4. Registro de compras
El sistema lleva un registro de lo que el jugador compró, cuánto compró, cuándo lo compró y cuánto dinero gastó, lo que transmite confianza y transparencia.<br>
Se muestra solo las últimas 20 compras, para no saturar los chats ni las vistas.<br>
Cabe añadir que los resultados se arreglan de manera cronológica, mostrando lo más reciente arriba.

<img width="775" height="392" alt="image" src="https://github.com/user-attachments/assets/5d3fbcfa-109e-4b09-9f9f-0a88f996af1b" />


# Cómo usar
<img width="1239" height="582" alt="image" src="https://github.com/user-attachments/assets/6b94d9ad-944b-4927-88bd-c9eab50dd54f" />

Se escribe nombre o parte del nombre del objeto en español, por ejemplo: 'paño de'
<img width="1169" height="610" alt="image" src="https://github.com/user-attachments/assets/5d0ce4d8-d4ef-4de1-ade5-20693b4dcd3e" />


Resultados:<br>
<img width="768" height="1079" alt="image" src="https://github.com/user-attachments/assets/85315231-5331-4fe8-bc37-165d6e2293b4" />

En los resultados impresos por el chat, el jugador puede clickear los links y verificar que el objeto que busca es el correcto.

Luego se ingresa la cantidad que desea:

<img width="413" height="126" alt="image" src="https://github.com/user-attachments/assets/40f5bbe8-2f4e-4281-9b74-5527058a1642" /><br>
<img width="445" height="168" alt="image" src="https://github.com/user-attachments/assets/35dfce8b-1581-44fe-8cba-4a547952a6df" /><br>



Se realiza la compra ofreciendo feedback constante del estado del sistema en el chat:<br>
<img width="1224" height="746" alt="image" src="https://github.com/user-attachments/assets/6e6f4fae-abb6-4088-a7aa-2c8e0e9a6d79" />


