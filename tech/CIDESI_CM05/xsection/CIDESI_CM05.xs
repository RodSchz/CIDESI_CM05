# ===== CMOS con LOCOS, sin spacers/silicide, sin W-plugs
#      Un solo IMD en salida (PMD + IMD)
#      M1–Via1–M2 (subtractive metal)
# =================================================================================================

# --- Parámetros (puedes ajustarlos) ---
gox_t  = 0.0294  # 29.4 nm, TCAD CM05v3 (30 nm nominal). Manual de
                 # referencia v1, Tabla 1. El comentario anterior decia
                 # 50 nm y nunca correspondio a este valor.
fox_u  = 0.31    # LOCOS "up" (altura). Campo de 0.66 um tras las
                 # limpiezas (Manual v1, Etapa B): 0.80 al crecer
                 # menos 0.14 que se van por arriba.
fox_i  = 0.35    # LOCOS "in" (hacia adentro)
pmd_t  = 0.20    # dieléctrico antes de M1
imd_t  = 1.50    # dieléctrico entre M1 y M2
m_t    = 0.25    # espesor metal (M1/M2)
over   = 0.05    # sobre-etch margen
nw_de  = 1.27    # Profundidad de pozo Nwell. TCAD: union a 1.27 um
                 # bajo la superficie del Si (Manual v1, Etapa A).
pol_t  = 0.25    # Grosor de Polisilicio
imd_pl = 0.0     # CMP del IMD. Hoy el proceso NO tiene planarizacion
                 # (es la razon de ser de la regla 8.5 de DRC). Queda
                 # parametrizado: subir este numero es lo unico que
                 # hay que hacer si algun dia se incorpora.
ovgl_t = 0.50    # Pasivación 

delta(5 * dbu)
depth(3)     # profundidad de sustrato simulada
height(5)    # ESPACIO SOBRE LA OBLEA - sin esto el default de 2 um
             # recorta M2 y la pasivacion

# ======== Máscaras desde layout ==================================================================
lwn    = layer("42/0")   # Nwell
lact   = layer("43/0")   # Active
lpoly  = layer("46/0")   # Poly
lhres  = layer("34/0")   # Hres
lcntp  = layer("47/0")   # Contact Poly
lcnta  = layer("48/0")   # Contact Active
lm1    = layer("49/0")   # Metal1 patrón
lvia1  = layer("50/0")   # Via1 patrón
lm2    = layer("51/0")   # Metal2 patrón
lnsel  = layer("45/0")   # Nselect
lpsel  = layer("44/0")   # Pselect
lovgl  = layer("52/0")   # Overglass

lfox   = lact.inverted   # campo para LOCOS
lpall  = lpoly.or(lhres) # Junta ambas capas de poly

# ======== Sustrato y pozos =======================================================================
pbulk  = bulk
nwell  = mask(lwn).grow(nw_de, -0.05, :mode => :round, :into => pbulk)

# ======== Aislamiento de campo (LOCOS) ===========================================================
mfox   = mask(lfox)
fox_up = mfox.grow(fox_u,  fox_u,  :bias => 0.10, :mode => :round)
fox_in = mfox.grow(fox_i,  fox_i,  :bias => 0.10, :mode => :round, :into => [pbulk, nwell])
fox    = fox_up.or(fox_in)

# ======== GOX y POLY =============================================================================
gox    = deposit(gox_t)                                      # Oxido de compuerta
poly   = mask(lpall).grow(pol_t, -0.05, :mode => :round)     # Polisilicio
mask(lpall.inverted).etch(gox_t, :into => gox)               # Ataque de GOX no protegido por poly

# ======== Implantación S/D (sin spacers/silicide) ========
nd     = mask(lact.and(lnsel)).grow(0.20, -0.05, :into => pbulk, :mode => :round)   # N+ en p-sub
pd     = mask(lact.and(lpsel)).grow(0.20, -0.05, :into => nwell, :mode => :round)   # P+ en nwell

# ============================================================
#             Aislamiento y Metalización (sin W-plugs)
# ============================================================

# --- PMD (Pre-Metal Dielectric) ---
pmd1 = deposit(pmd_t, pmd_t, :mode => :round)

# --- Apertura de contactos a S/D/Poly ---
#     Aseguramos perforar PMD y cualquier GOX que quede debajo del contacto.
mask(lcnta.or(lcntp)).etch(pmd_t, :into => pmd1, :taper => 5)

# --- Metal 1: depósito, planarizado simbólico y patrón subtractivo ---
m1_mat = deposit(m_t, m_t)
mask(lm1.inverted).etch(2*m_t+0.02, :into => m1_mat, :taper => 5)

# --- IMD entre M1 y M2 (mismo “tipo” que PMD) ---
imd = deposit(imd_t, imd_t, :mode => :round)
planarize(:into => [imd], :less => imd_pl) if imd_pl > 0.0   # CMP del IMD

# --- Apertura Via1 (hasta M1) ---
mask(lvia1).etch(imd_t + over, :into => imd, :taper => 5)

# --- Metal 2: depósito, CMP y patrón ---
m2_mat = deposit(m_t, m_t)
#planarize(:into => [m2_mat], :less => m_t)
mask(lm2.inverted).etch(3*m_t + 0.02, :into => m2_mat, :taper => 5)

ovg_mat = deposit(ovgl_t,ovgl_t)
mask(lovgl).etch(3*ovgl_t, :into => ovg_mat, :taper => 5)
planarize(:into => [ovg_mat], :less => 0.3)

# ======== Salidas (puedes mapearlas a tus capas .lyp) ========
imd_all = pmd1.or(imd)            # un solo IMD en salida

output("300/0", nwell)           # N-WELL
output("301/0", fox)             # LOCOS FOX
output("301/1", gox)             # GOX (sobre compuerta y donde no se abrió)
output("302/0", poly)            # POLY
output("303/0", nd)              # N+ S/D
output("304/0", pd)              # P+ S/D
output("308/0", imd_all)         # IMD único (PMD + IMD)  <-- cámbialo a "52/0" si prefieres Glass.drawing
output("309/0", pbulk)           # Substrato
output("311/0", m1_mat)          # METAL1
output("312/0", m2_mat)          # METAL2
output("313/0", ovg_mat)         # Pasivación