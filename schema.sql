-- ═══════════════════════════════════════════════════════════════════
-- RetornaCírculo · Esquema SQL v1.0
-- Sistema B2B de trazabilidad de envases · Ley REP Chile 20.920
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. EMPRESAS (productores / importadores / gestores) ──────────
CREATE TABLE empresas (
  id              SERIAL PRIMARY KEY,
  rut             VARCHAR(12) UNIQUE NOT NULL,          -- '76.543.210-9'
  razon_social    VARCHAR(200) NOT NULL,
  tipo            VARCHAR(20) CHECK (tipo IN (
                    'PRODUCTOR','IMPORTADOR','GESTOR','DISTRIBUIDOR'
                  )) NOT NULL,
  region          VARCHAR(50) NOT NULL,
  retc_codigo     VARCHAR(30),                          -- código inscripción RETC
  sig_id          VARCHAR(30),                          -- sistema colectivo (GIRO, etc.)
  activa          BOOLEAN DEFAULT TRUE,
  creada_en       TIMESTAMPTZ DEFAULT NOW()
);

-- ── 2. ENVASES (unidades físicas trazadas con QR) ─────────────────
CREATE TABLE envases (
  id              SERIAL PRIMARY KEY,
  qr_code         VARCHAR(40) UNIQUE NOT NULL,          -- 'QR-ENV-CL-00084217'
  empresa_id      INT REFERENCES empresas(id) ON DELETE RESTRICT,
  material        VARCHAR(20) CHECK (material IN (
                    'PET','VIDRIO','CARTON','METAL','PLASTICO_RIGIDO','OTRO'
                  )) NOT NULL,
  peso_kg         DECIMAL(8,3) NOT NULL,
  capacidad_l     DECIMAL(6,2),
  estado          VARCHAR(20) CHECK (estado IN (
                    'EN_CAMPO','EN_TRANSITO','RETORNADO','VALORIZADO','RECHAZADO'
                  )) DEFAULT 'EN_CAMPO',
  lote            VARCHAR(40),
  registrado_en   TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_envases_empresa ON envases(empresa_id);
CREATE INDEX idx_envases_material ON envases(material);
CREATE INDEX idx_envases_estado ON envases(estado);
CREATE INDEX idx_envases_qr ON envases(qr_code);

-- ── 3. PUNTOS DE RETORNO (Reverse Vending Machines / centros) ─────
CREATE TABLE puntos_retorno (
  id              SERIAL PRIMARY KEY,
  nombre          VARCHAR(150) NOT NULL,
  tipo            VARCHAR(20) CHECK (tipo IN (
                    'RVM','CENTRO_ACOPIO','MOVIL','PUERTA_A_PUERTA'
                  )) NOT NULL,
  empresa_id      INT REFERENCES empresas(id),          -- operador del punto
  latitud         DECIMAL(9,6),
  longitud        DECIMAL(9,6),
  region          VARCHAR(50),
  materiales      TEXT[],                               -- ['PET','VIDRIO']
  activo          BOOLEAN DEFAULT TRUE,
  capacidad_kg    DECIMAL(10,2),
  creado_en       TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_puntos_region ON puntos_retorno(region);

-- ── 4. EVENTOS (event sourcing · log inmutable) ───────────────────
CREATE TABLE eventos (
  id              BIGSERIAL PRIMARY KEY,
  envase_id       INT REFERENCES envases(id) ON DELETE RESTRICT,
  punto_id        INT REFERENCES puntos_retorno(id),
  tipo_evento     VARCHAR(30) CHECK (tipo_evento IN (
                    'REGISTRO','DESPACHO','RECEPCION','ESCANEO_QR',
                    'RETORNO_OK','RETORNO_CONTAMINADO','RECHAZADO_PESO',
                    'EN_TRANSITO','VALORIZADO','REPORTADO_RETC'
                  )) NOT NULL,
  peso_real_kg    DECIMAL(8,3),
  operador        VARCHAR(100),                         -- usuario/dispositivo
  lat             DECIMAL(9,6),
  lng             DECIMAL(9,6),
  metadata        JSONB,                               -- datos extras flexibles
  ocurrido_en     TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_eventos_envase ON eventos(envase_id);
CREATE INDEX idx_eventos_tipo ON eventos(tipo_evento);
CREATE INDEX idx_eventos_fecha ON eventos(ocurrido_en DESC);
CREATE INDEX idx_eventos_punto ON eventos(punto_id);

-- ── 5. CICLOS REP (períodos de cumplimiento por empresa) ──────────
CREATE TABLE ciclos_rep (
  id              SERIAL PRIMARY KEY,
  empresa_id      INT REFERENCES empresas(id) ON DELETE CASCADE,
  anio            SMALLINT NOT NULL,
  fase            SMALLINT CHECK (fase BETWEEN 1 AND 5) NOT NULL,
  meta_retorno_pct DECIMAL(5,2) NOT NULL,              -- ej. 40.00 %
  envases_total   INT DEFAULT 0,
  envases_retorno INT DEFAULT 0,
  tasa_real_pct   DECIMAL(5,2) GENERATED ALWAYS AS (
                    CASE WHEN envases_total > 0
                    THEN ROUND(envases_retorno * 100.0 / envases_total, 2)
                    ELSE 0 END
                  ) STORED,
  en_meta         BOOLEAN GENERATED ALWAYS AS (
                    CASE WHEN envases_total > 0
                    THEN (envases_retorno * 100.0 / envases_total) >= meta_retorno_pct
                    ELSE FALSE END
                  ) STORED,
  reporte_retc    JSONB,                               -- payload exportable al RETC
  estado          VARCHAR(20) DEFAULT 'ACTIVO' CHECK (
                    estado IN ('ACTIVO','CERRADO','REPORTADO','FISCALIZADO')
                  ),
  creado_en       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(empresa_id, anio)
);

-- ── 6. CERTIFICADOS (evidencia exportable) ────────────────────────
CREATE TABLE certificados (
  id              SERIAL PRIMARY KEY,
  ciclo_id        INT REFERENCES ciclos_rep(id) ON DELETE CASCADE,
  tipo            VARCHAR(30) CHECK (tipo IN (
                    'RETORNO','VALORIZACION','CUMPLIMIENTO_REP','CO2'
                  )) NOT NULL,
  folio           VARCHAR(60) UNIQUE NOT NULL,         -- 'RC-2026-0001-CV'
  hash_sha256     CHAR(64) NOT NULL,                   -- integridad
  emitido_en      TIMESTAMPTZ DEFAULT NOW(),
  vigente_hasta   DATE,
  datos           JSONB NOT NULL                       -- payload certificado
);
CREATE INDEX idx_certificados_ciclo ON certificados(ciclo_id);

-- ── VISTA DE MONITORING ──────────────────────────────────────────
CREATE VIEW v_dashboard AS
SELECT
  e.id           AS empresa_id,
  e.razon_social,
  e.tipo,
  cr.anio,
  cr.fase,
  cr.meta_retorno_pct,
  cr.envases_total,
  cr.envases_retorno,
  cr.tasa_real_pct,
  cr.en_meta,
  COUNT(ev.id) FILTER (WHERE ev.tipo_evento = 'VALORIZADO') AS eventos_valorizados,
  SUM(ev.peso_real_kg) FILTER (WHERE ev.tipo_evento = 'RETORNO_OK') AS kg_retornados
FROM empresas e
  LEFT JOIN ciclos_rep cr ON cr.empresa_id = e.id
  LEFT JOIN envases en    ON en.empresa_id = e.id
  LEFT JOIN eventos ev    ON ev.envase_id = en.id
WHERE e.activa = TRUE
GROUP BY e.id, e.razon_social, e.tipo, cr.anio, cr.fase,
         cr.meta_retorno_pct, cr.envases_total, cr.envases_retorno,
         cr.tasa_real_pct, cr.en_meta;
