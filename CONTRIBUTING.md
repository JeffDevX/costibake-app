# 🧁 Guía de Contribución y Estándares de Ingeniería

¡Bienvenido al repositorio de desarrollo de **CostiBake**! Esta guía define el protocolo de ingeniería, flujo de ramas **GitFlow** y convenciones de código para garantizar la mantenibilidad, calidad y estabilidad del proyecto.

---

## 1. Modelo de Ramas: GitFlow

Todas las contribuciones se realizan mediante ramas temporales y Pull Requests. **Nunca se hace commit directo a `main` ni a `dev`**.

### Topología de Ramas
* **`main`**: Rama de producción. Solo recibe merges provenientes de ramas `release/*` o `hotfix/*`.
* **`dev`**: Rama base de integración continua. Toda característica o corrección se fusiona aquí.
* **`feature/JEF-<ticket>-<nombre>`**: Nuevas funcionalidades (ej. `feature/JEF-5-arquitectura-base`). Se originan y terminan en `dev`.
* **`bugfix/JEF-<ticket>-<nombre>`**: Corrección de bugs no críticos detectados durante pruebas.
* **`release/v<version>`**: Rama de estabilización previa a un corte de producción.
* **`hotfix/v<version>`**: Parches críticos directos sobre `main`.

---

## 2. Convención de Mensajes de Commit

Seguimos la especificación de **Conventional Commits**:

`<tipo>(<alcance>): <descripción imperativa en español> (<ticket Linear>)`

### Tipos Permitidos
* `feat`: Nueva funcionalidad para el usuario.
* `fix`: Corrección de un defecto o bug.
* `refactor`: Cambio de código sin modificar la funcionalidad externa.
* `test`: Adición o refactorización de pruebas unitarias o de integración.
* `chore`: Cambios de configuración, dependencias o tooling.
* `docs`: Modificaciones exclusivas a la documentación.
* `perf`: Mejoras de rendimiento o consumo de recursos.

### Ejemplos
```bash
feat(catalog): agregar cálculo de costo base por unidad mínima (JEF-7)
fix(converter): corregir factor de densidad para azúcar glass (JEF-12)
test(engine): validar recálculo de costos en cascada (JEF-9)
```

---

## 3. Protocolo de Pull Requests (PR)

1. **Crear la rama:**
   ```bash
   git checkout dev
   git pull origin dev
   git checkout -b feature/JEF-XX-mi-funcionalidad
   ```
2. **Desarrollar y probar localmente:**
   - Formatear el código: `dart format .`
   - Ejecutar análisis estático: `flutter analyze`
   - Ejecutar pruebas: `flutter test`
3. **Subir cambios y abrir PR:**
   - Abrir Pull Request con destino a `dev`.
   - Completar todos los campos del template de PR (`.github/PULL_REQUEST_TEMPLATE.md`).
   - Vincular el ticket correspondiente de Linear (`JEF-XX`).
4. **Validación:**
   - El pipeline de CI de GitHub Actions debe estar en verde.
   - Todo PR debe ser revisado antes de hacer merge.
