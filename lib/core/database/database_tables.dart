/// DDL and SQL definitions for SQLite local relational schema.
class DatabaseTables {
  static const String tableInsumo = 'INSUMO';
  static const String tableEmpaque = 'EMPAQUE';
  static const String tableReceta = 'RECETA';
  static const String tableRecetaInsumo = 'RECETA_INSUMO';
  static const String tableRecetaEmpaque = 'RECETA_EMPAQUE';
  static const String tableConfiguracionNegocio = 'CONFIGURACION_NEGOCIO';

  static const String createTableInsumo = '''
    CREATE TABLE IF NOT EXISTS $tableInsumo (
      id TEXT PRIMARY KEY NOT NULL,
      nombre TEXT NOT NULL,
      categoria TEXT NOT NULL,
      costo_compra TEXT NOT NULL,
      cantidad_compra TEXT NOT NULL,
      unidad_compra TEXT NOT NULL,
      merma_porcentaje TEXT NOT NULL DEFAULT '0.0000',
      costo_unitario_minimo TEXT NOT NULL,
      unidad_minima TEXT NOT NULL,
      densidad_g_ml TEXT,
      notas TEXT,
      fecha_actualizacion TEXT NOT NULL
    );
  ''';

  static const String createTableEmpaque = '''
    CREATE TABLE IF NOT EXISTS $tableEmpaque (
      id TEXT PRIMARY KEY NOT NULL,
      nombre TEXT NOT NULL,
      categoria TEXT NOT NULL,
      costo_paquete TEXT NOT NULL,
      unidades_por_paquete INTEGER NOT NULL,
      costo_unitario TEXT NOT NULL,
      notas TEXT,
      fecha_actualizacion TEXT NOT NULL
    );
  ''';

  static const String createTableReceta = '''
    CREATE TABLE IF NOT EXISTS $tableReceta (
      id TEXT PRIMARY KEY NOT NULL,
      nombre TEXT NOT NULL,
      descripcion TEXT,
      porciones_rendimiento INTEGER NOT NULL DEFAULT 1,
      tiempo_preparacion_minutos INTEGER NOT NULL DEFAULT 0,
      tiempo_horneado_minutos INTEGER NOT NULL DEFAULT 0,
      tamano_molde_tipo TEXT,
      tamano_molde_dimension TEXT,
      margen_ganancia_porcentaje TEXT NOT NULL DEFAULT '40.0000',
      estado TEXT NOT NULL DEFAULT 'ACTIVA',
      fecha_creacion TEXT NOT NULL,
      fecha_actualizacion TEXT NOT NULL
    );
  ''';

  static const String createTableRecetaInsumo = '''
    CREATE TABLE IF NOT EXISTS $tableRecetaInsumo (
      id TEXT PRIMARY KEY NOT NULL,
      receta_id TEXT NOT NULL,
      insumo_id TEXT NOT NULL,
      cantidad TEXT NOT NULL,
      unidad TEXT NOT NULL,
      notas TEXT,
      FOREIGN KEY (receta_id) REFERENCES $tableReceta(id) ON DELETE CASCADE,
      FOREIGN KEY (insumo_id) REFERENCES $tableInsumo(id) ON DELETE RESTRICT
    );
  ''';

  static const String createTableRecetaEmpaque = '''
    CREATE TABLE IF NOT EXISTS $tableRecetaEmpaque (
      id TEXT PRIMARY KEY NOT NULL,
      receta_id TEXT NOT NULL,
      empaque_id TEXT NOT NULL,
      cantidad_piezas INTEGER NOT NULL DEFAULT 1,
      notas TEXT,
      FOREIGN KEY (receta_id) REFERENCES $tableReceta(id) ON DELETE CASCADE,
      FOREIGN KEY (empaque_id) REFERENCES $tableEmpaque(id) ON DELETE RESTRICT
    );
  ''';

  static const String createTableConfiguracionNegocio = '''
    CREATE TABLE IF NOT EXISTS $tableConfiguracionNegocio (
      id TEXT PRIMARY KEY NOT NULL,
      nombre_negocio TEXT NOT NULL,
      moneda_simbolo TEXT NOT NULL DEFAULT '\$',
      tarifa_hora_mano_obra TEXT NOT NULL DEFAULT '10.0000',
      porcentaje_overhead_indirectos TEXT NOT NULL DEFAULT '15.0000',
      fecha_actualizacion TEXT NOT NULL
    );
  ''';

  // Indexes for high-performance offline queries and joins
  static const List<String> createIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_insumo_nombre ON $tableInsumo(nombre);',
    'CREATE INDEX IF NOT EXISTS idx_insumo_categoria ON $tableInsumo(categoria);',
    'CREATE INDEX IF NOT EXISTS idx_empaque_nombre ON $tableEmpaque(nombre);',
    'CREATE INDEX IF NOT EXISTS idx_receta_nombre ON $tableReceta(nombre);',
    'CREATE INDEX IF NOT EXISTS idx_receta_insumo_receta ON $tableRecetaInsumo(receta_id);',
    'CREATE INDEX IF NOT EXISTS idx_receta_insumo_insumo ON $tableRecetaInsumo(insumo_id);',
    'CREATE INDEX IF NOT EXISTS idx_receta_empaque_receta ON $tableRecetaEmpaque(receta_id);',
    'CREATE INDEX IF NOT EXISTS idx_receta_empaque_empaque ON $tableRecetaEmpaque(empaque_id);',
  ];
}
