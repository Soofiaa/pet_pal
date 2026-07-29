# Backlog — PetPal

Consolidado a partir de las sesiones de trabajo de julio 2026. Cada ítem
incluye el problema u oportunidad real detrás, no solo la tarea técnica.

---

## Prioridad alta

### 1. Vista de "Hoy" / dashboard multi-mascota
**Problema:** toda la información (recordatorios, vencimientos, tratamientos
activos) vive encerrada dentro de cada mascota. Con más de una mascota, no
hay ningún lugar que muestre de un vistazo qué necesita atención hoy o esta
semana.
**Propuesta:** una sección al abrir la app (o al tope de `home_screen.dart`)
que combine `getAllEventsForPet` de todas las mascotas del usuario, ordenado
por urgencia/fecha.
**Por qué es la de mayor prioridad:** reutiliza infraestructura que ya
existe (el propio `getAllEventsForPet`, ya corregido y confiable tras la
sesión de hoy) — es el mayor payoff visible con el menor esfuerzo nuevo.
**Esfuerzo:** mediano. **Impacto:** alto.

### 2. Pruebas unitarias (DatabaseHelper / NotificationService)
**Problema:** en una sola sesión se encontraron tres bugs de falla
silenciosa que llevaban tiempo sin detectarse (integridad referencial nunca
aplicada, notificaciones sin receiver nativo, íconos de calendario rotos).
Ninguno lanzaba error ni lo detectaba `flutter analyze`.
**Propuesta:** suite acotada cubriendo específicamente estos patrones:
borrado en cascada, programación/cancelación de notificaciones, IDs sin
colisión.
**Por qué importa para tu perfil:** es la pieza de portafolio que más
directamente demuestra pensamiento de QA, no solo desarrollo.
**Esfuerzo:** mediano-grande. **Impacto:** alto (producto + portafolio).

---

## Prioridad media

### 3. Exportar historial a CSV/Excel
**Problema:** hay datos de salud reales y estructurados (peso, vacunas,
medicación) sin ninguna forma de sacarlos en un formato analizable fuera de
la app.
**Propuesta:** exportar por mascota a CSV/XLSX, reutilizando el mismo
patrón de `share_plus` ya usado en notas y backup.
**Por qué importa:** conecta directamente con el perfil de análisis de
datos/Power BI — hoy el proyecto no tiene ninguna pieza que lo demuestre.
**Esfuerzo:** chico-mediano. **Impacto:** medio (producto), alto
(portafolio).

### 4. Módulo de Signos Vitales (temperatura y similares)
**Problema:** originado en comentario de entrevista — necesidad real de
registrar mediciones frecuentes (ej. temperatura cada 2 horas) con mínima
fricción.
**Propuesta:** generalizar el patrón de `WeightRecord` (valor + fecha,
gráfico de tendencia) a signos vitales, con entrada rápida de un toque
(opcionalmente por voz, con `speech_to_text`), alertas de rango anormal
reutilizando `NotificationService`, y recordatorios con el mismo mecanismo
de horarios múltiples ya construido para medicación.
**Esfuerzo:** mediano. **Impacto:** alto (caso de uso real y bien
razonado).

### 5. GitHub Actions (CI)
**Problema:** sin validación automática en cada push.
**Propuesta:** workflow que corra `flutter analyze` + `flutter test`.
**Nota:** tiene más valor una vez que exista la suite de tests (ítem 2);
antes de eso, solo correría `analyze`.
**Esfuerzo:** chico. **Impacto:** medio.

### 6. Refactor arquitectónico (repository + estado)
**Problema:** las pantallas llaman directo a `DatabaseHelper()`, sin capa
intermedia; el estado se maneja con `setState` disperso.
**Propuesta:** introducir un patrón repository y algún manejo de estado
(Provider o Riverpod).
**Por qué importa:** hace el código más testeable y es justo el tipo de
decisión de diseño que se pregunta en entrevistas para roles junior
backend/funcional.
**Esfuerzo:** grande. **Impacto:** medio-alto (calidad de código,
portafolio).

---

## Prioridad baja / mantenimiento

### 7. Revisar carpeta de cuarentena de archivos huérfanos
Pendiente desde la limpieza de huérfanos: revisar manualmente
`petpal_files/_huerfanos_*` y decidir si se borra definitivamente.
**Esfuerzo:** trivial (revisión manual). **Impacto:** bajo, cierra un
pendiente abierto.

### 8. Conectar FoodAllergy al calendario
Hoy `FoodAllergy` no tiene `getEventsFromList` ni está conectado a
`getAllEventsForPet` — quedó deliberadamente fuera al corregir los
íconos rotos del calendario.
**Esfuerzo:** chico. **Impacto:** bajo-medio.

### 9. Cifrado del backup
Desde que `documents` incluye archivos médicos reales (exámenes,
cirugías), el ZIP de backup contiene información más sensible que antes.
**Esfuerzo:** mediano. **Impacto:** bajo por ahora (nadie más accede al
backup), pero crece si se comparte o sube a la nube.

### 10. Localización a inglés
Proyecto bilingüe como diferenciador de portafolio frente a reclutadores
que no leen español.
**Esfuerzo:** mediano-grande (traducción de toda la UI). **Impacto:**
medio, específico para portafolio.

### 11. Claves faltantes en iOS Info.plist
Faltan `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription` —
sin ellas, la app crashea al acceder a cámara/galería en iOS.
**Esfuerzo:** trivial. **Impacto:** nulo hoy (solo se compila para
Android), crítico el día que se compile para iOS.

### 12. Modo oscuro
Pulido general, bajo esfuerzo, no diferenciador.
**Esfuerzo:** chico-mediano. **Impacto:** bajo.

### 13. Insignias de estado en la lista de mascotas
Ícono en la tarjeta de cada mascota en `home_screen.dart` si tiene una
vacuna próxima o medicación activa — versión liviana del ítem 1 si ese
no se aborda primero.
**Esfuerzo:** chico. **Impacto:** medio (se vuelve redundante si se hace
el ítem 1).

---

*Última actualización: julio 2026, tras la sesión de notificaciones,
documentos, integridad de datos y calendario.*
