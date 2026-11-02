-- Reglamento de Próxima RP. Edítalo aquí: se muestra en el panel (Ayuda → Reglamento) y es buscable.
-- Cada regla: id, title, body (párrafos separados por \n\n) y, opcional, points (lista).
PXDRules = {
    intro = 'Próxima RP es una ciudad de rol. Venimos a contar historias juntos: tu personaje vive, siente y tiene consecuencias. '
        .. 'Estas normas existen para que la experiencia sea buena para todos. Desconocerlas no exime de cumplirlas.',
    list = {
        {
            id = 'basicos', title = 'Conceptos básicos: IC y OOC',
            body = 'IC (dentro del personaje) es todo lo que vive tu personaje. OOC (fuera del personaje) es lo que sabes o haces tú como jugador.',
            points = {
                'Mantén el rol en todo momento mientras estés en la ciudad.',
                'Usa /me para describir acciones que el juego no muestra («/me revisa el maletero»).',
                'Usa /b (o /ooc) solo para lo imprescindible (dudas técnicas, avisos) y con respeto.',
                'Si algo falla, termina la escena con naturalidad y resuélvelo después por soporte.',
            },
        },
        {
            id = 'pg', title = 'PowerGaming (PG)',
            body = 'Hacer algo que tu personaje no podría hacer en la realidad o forzar el rol de otro sin darle opción a responder.',
            points = {
                'No fuerces resultados: «/me le quita el arma» no vale si el otro no tiene oportunidad de reaccionar.',
                'No aproveches mecánicas del juego que serían imposibles (subir montañas en un deportivo, curarte al instante en plena pelea).',
                'Respeta las limitaciones físicas y las heridas de tu personaje.',
            },
        },
        {
            id = 'mg', title = 'MetaGaming (MG)',
            body = 'Usar dentro del rol información que tu personaje no ha conseguido dentro del rol.',
            points = {
                'Lo que ves en streams, Discord o chats OOC no lo sabe tu personaje.',
                'Los nombres sobre las cabezas o en listas no son conocimiento de tu personaje.',
                'No uses llamadas externas (Discord, etc.) para pasar información en una escena.',
            },
        },
        {
            id = 'dm', title = 'DeathMatch (DM) y RDM',
            body = 'Atacar, herir o matar sin un motivo de rol suficiente y desarrollado. RDM es hacerlo al azar, sin ninguna interacción previa.',
            points = {
                'Toda agresión necesita un conflicto previo y rol que la justifique.',
                'Un insulto o una mirada no justifican disparar.',
                'Las peleas por diversión van a los modos de juego (F7), no a la ciudad.',
            },
        },
        {
            id = 'vdm', title = 'Vehicle DeathMatch (VDM)',
            body = 'Usar un vehículo como arma o atropellar sin motivo de rol.',
            points = {
                'No embistas vehículos ni personas como forma de ataque sin un rol que lo justifique.',
                'Conduce con un mínimo de realismo: los choques tienen consecuencias para tu personaje y tu vehículo.',
            },
        },
        {
            id = 'nlr', title = 'Nueva vida (NLR)',
            body = 'Si tu personaje queda inconsciente y no recibe atención, «despierta» sin recordar lo que provocó su caída.',
            points = {
                'No vuelvas al lugar de los hechos durante al menos 15 minutos.',
                'No busques venganza por lo que no recuerdas.',
                'Si te atienden los servicios médicos, recuerdas lo que tu personaje viviría según el rol médico.',
            },
        },
        {
            id = 'ck', title = 'Muerte de personaje (CK) y PK',
            body = 'CK es la muerte definitiva del personaje. PK es una pérdida de memoria parcial tras un suceso grave.',
            points = {
                'Un CK necesita la aprobación del staff y un rol que lo justifique, salvo que lo pida el propio dueño del personaje.',
                'Tras un CK no puedes usar nada que supiera ese personaje.',
                'Pon en juego la vida de tu personaje con sentido: el CK no es un castigo, es parte de la historia.',
            },
        },
        {
            id = 'vida', title = 'Valorar la vida y el miedo',
            body = 'Tu personaje quiere seguir vivo. Actúa como lo haría una persona real cuando su vida corre peligro.',
            points = {
                'Si te apuntan con un arma y estás en desventaja, coopera.',
                'No provoques a quien te está amenazando.',
                'Valora también la vida de los demás: rehenes, testigos y civiles no son objetos.',
            },
        },
        {
            id = 'combatlog', title = 'Desconexiones en mitad del rol',
            body = 'Salir del servidor para evitar una detención, una muerte o cualquier consecuencia está prohibido.',
            points = {
                'Si se te cae el juego, vuelve en cuanto puedas e informa a las personas de la escena.',
                'Si tienes que irte de verdad, avísalo por /b y deja la escena resuelta.',
            },
        },
        {
            id = 'seguras', title = 'Zonas seguras',
            body = 'En las zonas seguras no se permite ningún delito ni agresión: hospital, comisarías, ayuntamiento y zonas de aparición.',
            points = {
                'No inicies ni persigas un rol delictivo hacia o desde una zona segura.',
                'Huir a una zona segura para librarte de un rol también se sanciona.',
            },
        },
        {
            id = 'robos', title = 'Robos, atracos y secuestros',
            body = 'Los delitos grandes necesitan preparación, rol y una policía capaz de responder.',
            points = {
                'Respeta los mínimos de policía de servicio de cada robo (tiendas, joyería, bancos): si no los hay, no hay robo.',
                'No robes a personas recién aparecidas ni a trabajadores en plena tarea legal sin rol previo.',
                'Rehenes: deben ser reales y voluntarios en el rol, nunca compañeros de banda.',
                'Un secuestro no puede durar más de 30 minutos ni terminar en CK sin aprobación del staff.',
                'Negociar es parte del rol: escucha y da salida a la otra parte.',
            },
        },
        {
            id = 'bugs', title = 'Errores del juego, trampas y corrupción',
            body = 'Aprovechar fallos del juego, del servidor o de los scripts es una falta grave.',
            points = {
                'Si encuentras un fallo, repórtalo (F9 o Discord) y no lo uses.',
                'Prohibido usar menús, programas externos o cualquier trampa.',
                'La corrupción dentro de los cuerpos oficiales necesita rol coherente y aprobación del staff.',
            },
        },
        {
            id = 'respeto', title = 'Respeto y comportamiento OOC',
            body = 'Somos una comunidad. Dentro y fuera del rol, el respeto es obligatorio.',
            points = {
                'Prohibido el acoso, la discriminación y el odio de cualquier tipo, también en Discord.',
                'Los roles sensibles (violencia sexual, autolesiones, odio real) están prohibidos.',
                'Las discusiones OOC se resuelven por soporte, no en mitad de una escena.',
            },
        },
        {
            id = 'staff', title = 'Staff y reportes',
            body = 'El staff está para ayudar y para que se cumplan las normas. Sus decisiones se pueden recurrir por Discord, con calma y pruebas.',
            points = {
                'Para reportar, abre un ticket en Discord con tu ID, el del otro jugador y un clip si puedes.',
                'No interrumpas una escena para discutir una norma: termina el rol y repórtalo después.',
                'Mentir al staff o manipular pruebas se sanciona.',
            },
        },
        {
            id = 'sanciones', title = 'Sanciones',
            body = 'Las sanciones dependen de la gravedad y de si la falta se repite.',
            points = {
                'Aviso: faltas leves o primera vez.',
                'Expulsión temporal del servidor.',
                'Suspensión de varios días.',
                'Expulsión permanente: trampas, acoso grave o faltas graves repetidas.',
                'El staff puede saltarse pasos si la falta es grave.',
            },
        },
    },
}
