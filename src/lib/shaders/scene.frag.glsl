#version 300 es
precision highp float;
out vec4 fragColor;
uniform vec2  iResolution;
uniform float iTime;
uniform vec2  iMouse;
uniform float uHover;
uniform float uActive;
uniform vec3  uCamRo;
uniform vec3  uCamTarget;
uniform float uCamFocal;
uniform float uViewBias;
uniform vec3  uOrbA[8];
uniform vec3  uOrbB[8];
uniform float uOrbR[8];
uniform float uOrbCount;

/* ---------- utility ---------- */
#define PI 3.14159265
float hash11(float n){ return fract(sin(n*127.1)*43758.5453123); }
float hash21(vec2 p){ p = fract(p*vec2(123.34,456.21)); p += dot(p,p+45.32); return fract(p.x*p.y); }
mat2 rot2(float a){ float c=cos(a),s=sin(a); return mat2(c,-s,s,c); }

float vnoise(vec2 p){
  vec2 i = floor(p), f = fract(p);
  f = f*f*(3.0-2.0*f);
  return mix(mix(hash21(i),          hash21(i+vec2(1.,0.)), f.x),
             mix(hash21(i+vec2(0.,1.)), hash21(i+vec2(1.,1.)), f.x), f.y);
}
/* value noise con derivate analitiche: una sola valutazione dà anche la
   pendenza, così le normali procedurali non costano altre fbm */
vec3 vnoiseD(vec2 p){
  vec2 i = floor(p), f = fract(p);
  vec2 u = f*f*(3.0-2.0*f), du = 6.0*f*(1.0-f);
  float a = hash21(i), b = hash21(i+vec2(1.,0.));
  float c = hash21(i+vec2(0.,1.)), d = hash21(i+vec2(1.,1.));
  float k1 = b-a, k2 = c-a, k3 = a-b-c+d;
  return vec3(a + k1*u.x + k2*u.y + k3*u.x*u.y,
              du.x*(k1 + k3*u.y),
              du.y*(k2 + k3*u.x));
}
float fbm2(vec2 p){ return 0.62*vnoise(p) + 0.38*vnoise(p*2.07+11.3); }

float sdBox(vec3 p, vec3 b){ vec3 q=abs(p)-b; return length(max(q,0.))+min(max(q.x,max(q.y,q.z)),0.); }
float sdRoundBox(vec3 p, vec3 b, float r){ vec3 q=abs(p)-b; return length(max(q,0.))+min(max(q.x,max(q.y,q.z)),0.)-r; }
float sdSphere(vec3 p, float r){ return length(p)-r; }
float sdCylinder(vec3 p, float h, float r){ vec2 d=abs(vec2(length(p.xz),p.y))-vec2(r,h); return min(max(d.x,d.y),0.)+length(max(d,0.)); }
float sdTorus(vec3 p, vec2 t){ vec2 q=vec2(length(p.xz)-t.x,p.y); return length(q)-t.y; }
float sdRect2(vec2 p, vec2 b){ vec2 q=abs(p)-b; return length(max(q,0.))+min(max(q.x,q.y),0.); }
float sdRoundCone(vec3 p, float r1, float r2, float h){
  vec2 q=vec2(length(p.xz),p.y);
  float b=(r1-r2)/h, a=sqrt(1.-b*b), k=dot(q,vec2(-b,a));
  if(k<0.) return length(q)-r1;
  if(k>a*h) return length(q-vec2(0.,h))-r2;
  return dot(q,vec2(a,b))-r1;
}
float sdCapsule(vec3 p, vec3 a, vec3 b, float r){
  vec3 pa=p-a, ba=b-a;
  float h=clamp(dot(pa,ba)/dot(ba,ba),0.,1.);
  return length(pa-ba*h)-r;
}
float smin(float a, float b, float k){
  float h=clamp(0.5+0.5*(b-a)/k,0.,1.);
  return mix(b,a,h)-k*h*(1.-h);
}
vec2 opU(vec2 a, vec2 b){ return a.x<b.x?a:b; }

/* Bound conservativo di un box: solo la componente di Chebyshev, senza la
   length() di sdBox. Fuori dal box vale sempre max(q) <= distanza reale,
   quindi il march resta corretto; sottostima solo in diagonale agli spigoli.
   Usato per tutti i test di gruppo, dove serve un limite inferiore e non
   la distanza esatta: taglia 13 radici quadrate per passo di march. */
float bnd(vec3 p, vec3 c, vec3 b){
  vec3 q = abs(p-c)-b;
  return max(q.x, max(q.y, q.z));
}

/* rettangolo con angoli tagliati a 45° (aperture/telai da habitat) */
float sdOctRect(vec2 p, vec2 b, float c){
  vec2 a = abs(p);
  return max(max(a.x-b.x, a.y-b.y), (a.x+a.y-(b.x+b.y-c))*0.70710678);
}
/* box con smussi indipendenti su spigoli verticali, alto e basso */
float sdChamferBox(vec3 p, vec3 b, float cv, float ct, float cb){
  float d = sdBox(p,b);
  vec3 a = abs(p);
  d = max(d, (a.x + a.z - (b.x + b.z - cv))*0.70710678);
  d = max(d, (a.x + p.y - (b.x + b.y - ct))*0.70710678);
  d = max(d, (a.z + p.y - (b.z + b.y - ct))*0.70710678);
  d = max(d, (a.x - p.y - (b.x + b.y - cb))*0.70710678);
  d = max(d, (a.z - p.y - (b.z + b.y - cb))*0.70710678);
  return d;
}

/* ---------- layout ---------- */
const vec3  ROOM_C   = vec3(0.0, 1.60, -0.40);
const vec3  ROOM_IH  = vec3(3.60, 1.60, 3.28);
const float CH_VERT  = 0.52;   /* smusso spigoli verticali */
const float CH_TOP   = 0.34;   /* smusso parete/soffitto */
const float CH_BOT   = 0.10;   /* battiscopa */

const vec3  WIN_C  = vec3(0.,1.8,-3.80);
const vec2  WIN_B  = vec2(2.95,1.12);
const float WIN_CH = 0.50;
const float WALL_F = -3.68;    /* faccia interna parete finestra */
const float GLASS_Z = -3.74;

const vec3 TAB_C = vec3(-0.70,0.83,0.80);
const vec3 BRD_C = vec3(0.58,0.805,0.82);
const vec3 OCT_C = vec3(1.12,0.80,1.10);
const vec3 DESK_C = vec3(0.,0.75,0.85);
const vec3 BED_C  = vec3(2.55,0.34,-1.60);

const vec3 SAT_DIR = vec3(-0.28801,0.16321,-0.94357); /* normalize(-0.30,0.17,-1.0) */

const float OCT_YAW = atan(0.0 - OCT_C.x, 2.10 - OCT_C.z);
vec3 octToLocal(vec3 q){
  float c = cos(OCT_YAW), s = sin(OCT_YAW);
  return vec3(c*q.x - s*q.z, q.y, s*q.x + c*q.z);
}
vec3 orbPos(int i){
  float fi = float(i);
  float n = max(uOrbCount, 1.0);
  float z = 1.18 - (n <= 1.0 ? 0.0 : (fi / (n - 1.0)) * 0.48);
  float xOff = (mod(fi, 2.0) < 0.5) ? -0.05 : 0.25;
  float r = uOrbR[i];
  return vec3(-0.22 + xOff, 0.795 + r + 0.015*sin(iTime*1.3+fi*1.9), z);
}
vec3 socialPos(int i){
  vec3 b;
  if(i==0) b=vec3(3.18,2.54,-1.50);
  else if(i==1) b=vec3(3.18,2.54,-0.70);
  else if(i==2) b=vec3(3.18,2.54, 0.10);
  else if(i==3) b=vec3(3.18,1.79,-1.20);
  else if(i==4) b=vec3(3.18,1.79,-0.20);
  else if(i==5) b=vec3(3.18,1.04,-1.20);
  else b=vec3(3.18,1.04,-0.20);
  b.y += 0.008*sin(iTime*1.4+float(i)*1.7);
  return b;
}
vec3 socialColorA(int i){
  if(i==0) return vec3(0.09,0.47,0.95);
  if(i==1) return vec3(0.90,0.25,0.55);
  if(i==2) return vec3(0.04,0.40,0.76);
  if(i==3) return vec3(0.15,0.65,0.90);
  if(i==4) return vec3(0.35,0.40,0.95);
  if(i==5) return vec3(0.95,0.12,0.12);
  return vec3(0.40,0.85,0.95);
}
vec3 socialColorB(int i){
  if(i==0) return vec3(0.35,0.65,1.0);
  if(i==1) return vec3(1.0,0.55,0.20);
  if(i==2) return vec3(0.25,0.65,0.95);
  if(i==3) return vec3(0.40,0.85,1.0);
  if(i==4) return vec3(0.55,0.50,1.0);
  if(i==5) return vec3(1.0,0.40,0.35);
  return vec3(0.70,0.95,1.0);
}

/* ============================================================
   LINE LIGHTS
   Tabelle const invece della catena di if: una sola indicizzazione
   dinamica per luce. 0..4 = "major", usate anche per il glow in aria
   e per i riflessi speculari; 5..8 solo diffusa ravvicinata.
   ============================================================ */
#define NLIGHT 9
#define NLIGHT_MAJOR 5

const vec3 LGT_A[NLIGHT] = vec3[NLIGHT](
  vec3(-2.14,3.150,-3.10), vec3( 2.14,3.150,-3.10),
  vec3(-1.52,0.695, 1.39), vec3( 1.55,0.22,-2.40), vec3(-2.86,0.672,-3.40),
  vec3(-1.53,0.695, 1.39), vec3( 1.53,0.695, 1.39),
  vec3(-3.40,1.595,-1.58), vec3( 3.44,1.595,-1.72)
);
const vec3 LGT_B[NLIGHT] = vec3[NLIGHT](
  vec3(-1.62,3.150, 1.95), vec3( 1.62,3.150, 1.95),
  vec3( 1.52,0.695, 1.39), vec3( 1.55,0.22,-0.64), vec3( 2.86,0.672,-3.40),
  vec3(-1.53,0.695, 0.33), vec3( 1.53,0.695, 0.33),
  vec3(-3.40,1.595, 0.68), vec3( 3.44,1.595, 0.28)
);
const vec3 LGT_C[NLIGHT] = vec3[NLIGHT](
  vec3(0.46,0.60,0.86)*2.15, vec3(0.46,0.60,0.86)*2.15,
  vec3(0.46,0.14,0.62)*0.85, vec3(0.18,0.62,1.05)*4.20, vec3(0.30,0.44,0.68)*0.95,
  vec3(0.42,0.10,0.86)*0.55, vec3(0.42,0.10,0.86)*0.55,
  vec3(0.11,0.36,0.66)*1.05, vec3(0.11,0.36,0.66)*0.95
);
const float LGT_R[NLIGHT] = float[NLIGHT](0.11,0.11,0.05,0.08,0.03,0.04,0.04,0.035,0.035);

vec3 segClosest(vec3 p, vec3 a, vec3 b){
  vec3 ab = b-a;
  float h = clamp(dot(p-a,ab)/max(dot(ab,ab),1e-5), 0.0, 1.0);
  return a + ab*h;
}

/* distanza minima raggio↔segmento, con t del punto di avvicinamento */
float raySegDist(vec3 ro, vec3 rd, vec3 a, vec3 b, out float tr){
  vec3 v = b-a, w = ro-a;
  float bb = dot(rd,v), cc = dot(v,v), dd = dot(rd,w), ee = dot(v,w);
  float den = cc - bb*bb;
  float sc, tc;
  if(den < 1e-5){ sc = -dd; tc = 0.0; }
  else { sc = (bb*ee - cc*dd)/den; tc = (ee - bb*dd)/den; }
  sc = max(sc, 0.0);
  tc = clamp(tc, 0.0, 1.0);
  tr = sc;
  return length((ro + rd*sc) - (a + v*tc));
}

/* contributo diffuso delle strisce.
   Niente speculare qui: il punto più vicino sul segmento sta sempre
   "sopra" una superficie orizzontale, quindi un lobo di Blinn-Phong
   coprirebbe uniformemente pavimento e scrivania. Lo speculare è
   gestito da stripGlow() lungo il raggio riflesso. */
vec3 stripLighting(vec3 pos, vec3 n, float ao){
  vec3 acc = vec3(0.0);
  for(int i=0;i<NLIGHT;i++){
    vec3 ld = segClosest(pos, LGT_A[i], LGT_B[i]) - pos;
    float d2 = dot(ld,ld);
    if(d2 > 30.0) continue;
    float nl = dot(n,ld);
    if(nl <= 0.0) continue;
    acc += LGT_C[i] * (nl*inversesqrt(d2)) / (1.0 + d2*0.95);
  }
  return acc*ao;
}

/* glow delle strisce lungo un raggio: volumetrica, riflessi lucidi, vetro.
   nlim limita quali luci (0,1 = solo plafoniere: serve al piano della scrivania
   perché la striscia viola frontale altrimenti sporca tutto il top). */
vec3 stripGlowN(vec3 ro, vec3 rd, float tmax, float k, int nlim){
  vec3 acc = vec3(0.0);
  for(int i=0;i<NLIGHT_MAJOR;i++){
    if(i >= nlim) break;
    float tr;
    float d = raySegDist(ro,rd,LGT_A[i],LGT_B[i],tr);
    if(tr <= 0.02 || tr > tmax) continue;
    float g = LGT_R[i]/(LGT_R[i] + d*d*k);
    acc += LGT_C[i]*g*g;
  }
  return acc;
}
vec3 stripGlow(vec3 ro, vec3 rd, float tmax, float k){
  return stripGlowN(ro, rd, tmax, k, NLIGHT_MAJOR);
}

/* ---------- occupazione scacchiera ---------- */
float occupancy(vec2 cell){
  float row = cell.y;
  if(row<1.5 || row>5.5) return 1.0;
  return step(hash21(cell+vec2(3.7,9.1)),0.10);
}
float pieceProfile(vec2 cell){
  float row=cell.y;
  if(row==1.0||row==6.0) return 0.0;
  if(row>1.5&&row<5.5) return 0.15;
  float c=min(cell.x,7.0-cell.x);
  if(c<0.5) return 0.35;
  if(c<1.5) return 0.5;
  if(c<2.5) return 0.65;
  return cell.x==3.0?1.0:0.88;
}

/* ============================================================
   MAPPA SDF

   Gli oggetti sono raggruppati dietro bounding box: se il raggio è
   fuori dal box si restituisce la distanza al box (che è sempre un
   limite inferiore della distanza al contenuto, quindi il march resta
   corretto) e si salta tutto il gruppo. La soglia 0.05 con box
   imbottiti evita che il bordo del volume venga preso per una
   superficie.

   ID materiali:
    2 shell stanza  4 top scrivania  5 metallo scuro  6 corpo tablet
    7 schermo tablet 8 scacchiera  10/11 pezzi  12 bezel finestra
    13 LED viola  14 LED ciano  15 materasso  16 coperta  19 cuscino
    17 tazza  20 diffusore plafoniera  21 condotto
    22 statuetta  23 cassa  24 octocat  25 metallo mensole
    26 bulkhead  27 accento ciano  28 display  29 grigliato
    30..36 social  40 piante  41 armi  42 tech  50..57 orbs
   ============================================================ */
#define GB 0.05

vec2 map(vec3 p){
  /* --- shell: guscio smussato con apertura ottagonale --- */
  vec3 rq = p - ROOM_C;
  float shell = max(sdBox(rq, ROOM_IH + vec3(0.32)),
                   -sdChamferBox(rq, ROOM_IH, CH_VERT, CH_TOP, CH_BOT));
  vec2 wl = p.xy - WIN_C.xy;
  float aperture = max(sdOctRect(wl, WIN_B, WIN_CH), abs(p.z - WIN_C.z) - 0.9);
  shell = max(shell, -aperture);
  vec2 res = vec2(shell, 2.0);

  /* ---------------- soffitto: plafoniere, HVAC, condotti ----------------
     Tutto il contenuto sta sopra y = 2.84, quindi la distanza al semispazio
     è già un bound valido: un flop invece di un box a sei facce. */
  {
    float gb = 2.84 - p.y;
    if(gb < GB){
      /* canali incassati delle plafoniere (sottrazione dallo shell) */
      vec3 gq = vec3(abs(p.x - p.z*0.098) - 1.88, p.y - 3.238, p.z + 0.62);
      res.x = max(res.x, -sdBox(gq, vec3(0.145,0.042,2.60)));
      res = opU(res, vec2(sdBox(vec3(gq.x, p.y - 3.262, gq.z), vec3(0.112,0.016,2.585)), 20.0));
      /* costole di irrigidimento a doppia T: 3 copie, un solo eval */
      {
        float bz = -2.6 + clamp(floor((p.z + 2.6)/1.9 + 0.5), 0.0, 2.0)*1.9;
        vec3 bq = p - vec3(0.0,3.13,bz);
        float beam = sdBox(bq, vec3(3.24,0.070,0.055));
        beam = min(beam, sdBox(bq - vec3(0.0,-0.085,0.0), vec3(3.20,0.016,0.115)));
        res = opU(res, vec2(beam, 26.0));
      }
      /* unità HVAC: alette solo da vicino */
      if(bnd(p, vec3(0.0,3.05,-1.50), vec3(0.92,0.22,0.52)) < GB){
        vec3 hq = p - vec3(0.0,3.05,-1.50);
        float hous = sdRoundBox(hq, vec3(0.86,0.145,0.44), 0.025);
        hous = max(hous, -sdBox(hq - vec3(0.0,-0.135,0.0), vec3(0.70,0.055,0.32)));
        res = opU(res, vec2(hous, 26.0));
        vec3 fq = hq - vec3(0.0,-0.155,0.0);
        fq.z = mod(fq.z + 0.045, 0.09) - 0.045;
        float fins = sdBox(fq, vec3(0.70,0.038,0.011));
        fins = max(fins, sdBox(hq - vec3(0.0,-0.14,0.0), vec3(0.70,0.06,0.31)));
        res = opU(res, vec2(fins, 5.0));
        res = opU(res, vec2(sdBox(hq - vec3(0.0,0.02,0.50), vec3(0.30,0.10,0.075)), 21.0));
      }
      /* condotti longitudinali con staffe ripetute */
      float px = abs(p.x) - 2.95;
      vec3 pq = vec3(px, p.y - 3.02, p.z);
      float pipe = sdCapsule(pq, vec3(0.,0.,-3.28), vec3(0.,0.,2.42), 0.058);
      pipe = min(pipe, sdCapsule(vec3(px, p.y - 3.02, p.z), vec3(0.10,-0.03,-3.28), vec3(0.10,-0.03,2.42), 0.032));
      vec3 cq = pq; cq.z = mod(cq.z + 0.40, 0.80) - 0.40;
      float clamp1 = sdBox(cq, vec3(0.075,0.085,0.018));
      clamp1 = max(clamp1, sdBox(pq, vec3(0.12,0.10,2.85)));
      res = opU(res, vec2(min(pipe, clamp1), 21.0));
      /* fascio di cavi lungo lo smusso parete/soffitto */
      float cx = abs(p.x) - 3.36;
      vec3 kq = vec3(cx, p.y - 2.97, p.z);
      float cable = sdCapsule(kq, vec3(0.,0.,-3.20), vec3(0.,0.,2.40), 0.034);
      cable = min(cable, sdCapsule(kq, vec3(0.045,-0.045,-3.20), vec3(0.045,-0.045,2.40), 0.026));
      res = opU(res, vec2(cable, 5.0));
    } else res.x = min(res.x, gb);
  }

  /* ---------------- finestra: bezel, labbro, sill, staffe ---------------- */
  {
    float gb = p.z + 3.39;
    if(gb < GB){
      float bez = sdOctRect(wl, WIN_B + vec2(0.015), WIN_CH);
      bez = max(bez, -sdOctRect(wl, WIN_B - vec2(0.20), WIN_CH - 0.14));
      bez = max(bez, abs(p.z + 3.755) - 0.075);
      res = opU(res, vec2(bez, 12.0));

      float lip = sdOctRect(wl, WIN_B - vec2(0.055), WIN_CH - 0.04);
      lip = max(lip, -sdOctRect(wl, WIN_B - vec2(0.105), WIN_CH - 0.07));
      lip = max(lip, abs(p.z + 3.685) - 0.016);
      res = opU(res, vec2(lip, 14.0));

      /* staffe a L agli angoli, come su un portello a pressione */
      vec2 aw = abs(wl);
      float brk = sdBox(vec3(aw.x - (WIN_B.x-0.80), aw.y - (WIN_B.y-0.045), p.z + 3.700), vec3(0.30,0.062,0.075));
      brk = min(brk, sdBox(vec3(aw.x - (WIN_B.x-0.045), aw.y - (WIN_B.y-0.74), p.z + 3.700), vec3(0.062,0.26,0.075)));
      brk = min(brk, sdBox(vec3(aw.x - (WIN_B.x-0.145), aw.y - (WIN_B.y-0.145), p.z + 3.690), vec3(0.115,0.115,0.055)));
      res = opU(res, vec2(brk, 26.0));

      /* mensola/sill sotto l'apertura, con squadrette di sostegno */
      float sill = sdRoundBox(p - vec3(0.0, 0.665, -3.545), vec3(3.05,0.055,0.145), 0.03);
      res = opU(res, vec2(sill, 26.0));
      res = opU(res, vec2(sdBox(p - vec3(0.0,0.665,-3.402), vec3(2.95,0.012,0.010)), 14.0));
      vec3 gq = vec3(abs(p.x) - 1.55, p.y - 0.53, p.z + 3.60);
      float guss = sdBox(gq, vec3(0.022,0.085,0.115));
      guss = max(guss, (-gq.y*0.6 - gq.z*0.8) - 0.04);
      res = opU(res, vec2(guss, 5.0));
      res = opU(res, vec2(sdCapsule(p, vec3(-2.60,0.545,-3.50), vec3(2.60,0.545,-3.50), 0.030), 21.0));
    } else res.x = min(res.x, gb);
  }

  /* grigliato di ventilazione a filo pavimento, sotto la finestra */
  {
    float gb = max(p.y - 0.058, p.z + 2.688);
    if(gb < GB){
      vec3 vq = p - vec3(0.0,0.022,-3.10);
      float grate = sdRoundBox(vq, vec3(1.52,0.022,0.40), 0.012);
      vec3 sq = vq; sq.x = mod(sq.x + 0.055, 0.11) - 0.055;
      float slot = max(sdBox(sq, vec3(0.030,0.030,0.33)), sdBox(vq, vec3(1.42,0.05,0.33)));
      res = opU(res, vec2(max(grate, -slot), 29.0));
    } else res.x = min(res.x, gb);
  }

  /* ---------------- scrivania e oggetti sul piano ---------------- */
  {
    float gb = bnd(p, vec3(0.0,0.45,0.85), vec3(1.82,0.60,0.82));
    if(gb < GB){
      vec3 dp = p - DESK_C;
      res = opU(res, vec2(sdRoundBox(dp, vec3(1.55,0.038,0.55),0.012), 4.0));
      /* due piedistalli pieni, come nel still */
      res = opU(res, vec2(sdRoundBox(vec3(abs(dp.x)-1.12, dp.y+0.395, dp.z+0.04), vec3(0.22,0.355,0.38), 0.02), 5.0));
      /* LED rientrato sotto il bordo anteriore: linea netta, niente bleed sul piano */
      float led = max(abs(dp.z - 0.552) - 0.006, abs(dp.x) - 1.46);
      led = max(led, abs(dp.y + 0.046) - 0.007);
      res = opU(res, vec2(led, 13.0));
      /* canalina cavi e matassa che scende dietro il piano */
      res = opU(res, vec2(sdBox(dp - vec3(0.0,-0.145,-0.36), vec3(1.20,0.038,0.055)), 26.0));
      res = opU(res, vec2(sdCapsule(p, vec3(0.92,0.585,0.50), vec3(1.02,0.30,0.44), 0.016), 5.0));
      res = opU(res, vec2(sdCapsule(p, vec3(1.02,0.30,0.44), vec3(1.06,0.06,0.62), 0.016), 5.0));

      /* props sul piano: il pavimento sotto la scrivania non li valuta */
      if(p.y > 0.68){
      /* tablet */
      if(bnd(p, TAB_C, vec3(0.26,0.14,0.20)) < GB){
        vec3 tp = p - TAB_C;
        tp.yz = rot2(0.5)*tp.yz;
        res = opU(res, vec2(sdRoundBox(tp, vec3(0.21,0.012,0.15),0.008), 6.0));
        res = opU(res, vec2(sdBox(tp-vec3(0.,0.024,0.), vec3(0.185,0.004,0.125)), 7.0));
      }

      /* scacchiera */
      if(bnd(p, BRD_C + vec3(0.,0.09,0.), vec3(0.28,0.14,0.28)) < GB){
        vec3 bp = p - BRD_C;
        res = opU(res, vec2(sdRoundBox(bp, vec3(0.24,0.018,0.24),0.008), 8.0));
        vec3 pp = bp - vec3(0.,0.018,0.);
        vec2 cell = clamp(floor(pp.xz/0.055+4.0), 0.0, 7.0);
        if(occupancy(cell)>0.5){
          vec2 cc = (cell-3.5)*0.055;
          vec3 lp = vec3(pp.x-cc.x, pp.y, pp.z-cc.y);
          float t = pieceProfile(cell);
          float h = 0.030+0.034*t;
          float d = sdRoundCone(lp, 0.016, 0.008, h);
          d = min(d, sdSphere(lp-vec3(0.,h+0.004,0.), 0.010+t*0.006));
          res = opU(res, vec2(d, cell.y<4.0 ? 10.0 : 11.0));
        }
      }

      /* octocat */
      if(bnd(p, OCT_C + vec3(0.,0.09,0.), vec3(0.24,0.20,0.24)) < GB){
        vec3 q = octToLocal(p - OCT_C);
        float wob = 0.008*sin(iTime*2.0);
        vec3 hq = q - vec3(0.,0.085+wob,0.);
        hq.y *= 0.82;
        float body = sdSphere(hq, 0.062);
        float legs = 1000.0;
        float sec = 6.2831853/6.0;
        for(int i=0;i<6;i++){
          float ai = float(i)*sec + 3.14159265;
          vec3 lq = vec3(cos(-ai)*q.x - sin(-ai)*q.z, q.y, sin(-ai)*q.x + cos(-ai)*q.z);
          float ph = ai*3.0 + iTime*1.6;
          vec3 tip = vec3(0.105+0.008*sin(ph), 0.012+0.006*cos(ph), 0.0);
          float leg = sdCapsule(lq, vec3(0.035,0.055,0.), vec3(0.075,0.020,0.), 0.020);
          leg = smin(leg, sdCapsule(lq, vec3(0.075,0.020,0.), tip, 0.014), 0.01);
          legs = min(legs, leg);
        }
        float ears = min(sdCapsule(hq, vec3(-0.030,0.042,0.010), vec3(-0.050,0.098,0.002), 0.011),
                         sdCapsule(hq, vec3( 0.030,0.042,0.010), vec3( 0.050,0.098,0.002), 0.011));
        float oct = smin(body, legs, 0.02);
        oct = smin(oct, ears, 0.012);
        res = opU(res, vec2(oct, 24.0));
      }

      /* sfere olografiche aziende + piedistalli */
      for(int i=0;i<8;i++){
        float r = uOrbR[i];
        if(r <= 0.0) continue;
        vec3 op = orbPos(i);
        res = opU(res, vec2(sdSphere(p-op, r), 50.0+float(i)));
        if(bnd(p, vec3(op.x,0.80,op.z), vec3(0.09,0.05,0.09)) < GB){
          res = opU(res, vec2(sdCylinder(p-vec3(op.x,0.795,op.z), 0.010,0.035), 5.0));
          res = opU(res, vec2(sdCylinder(p-vec3(op.x,0.806,op.z), 0.003,0.030), 14.0));
        }
      }

      /* tazza con manico */
      vec3 mp = p - vec3(1.18,0.85,0.60);
      float mug = sdCylinder(mp, 0.065, 0.045);
      mug = max(mug, -sdCylinder(mp - vec3(0.,0.020,0.), 0.062, 0.036));
      float handle = sdTorus(vec3(mp.x-0.042, mp.z, mp.y), vec2(0.032,0.008));
      handle = max(handle, -(0.042 - mp.x));
      res = opU(res, vec2(min(mug, handle), 17.0));
      }
    } else res.x = min(res.x, gb);
  }

  /* ---------------- letto ---------------- */
  {
    float gb = max(1.58 - p.x, abs(p.z + 1.64) - 1.16);
    if(gb < GB){
      vec3 ep = p - BED_C;
      /* pedana bassa, quasi nascosta dalle lenzuola */
      res = opU(res, vec2(sdRoundBox(ep-vec3(0.,-0.275,0.), vec3(0.78,0.055,0.94),0.015), 5.0));
      /* LED hover-pallet a filo pavimento */
      float bring = abs(sdRect2(ep.xz, vec2(0.90,1.04))) - 0.022;
      bring = max(bring, abs(ep.y + 0.332) - 0.018);
      res = opU(res, vec2(bring, 14.0));
      /* LED a filo della coperta, sulla faccia verso la stanza */
      float sideL = max(abs(ep.x + 0.99) - 0.018, abs(ep.y + 0.12) - 0.032);
      sideL = max(sideL, abs(ep.z - 0.18) - 0.78);
      float sideF = max(abs(ep.z - 0.96) - 0.018, abs(ep.y + 0.12) - 0.032);
      sideF = max(sideF, abs(ep.x) - 0.98);
      res = opU(res, vec2(min(sideL, sideF), 14.0));
      /* materasso plum, poco visibile sotto la coperta */
      res = opU(res, vec2(sdRoundBox(ep-vec3(0.,-0.02,0.), vec3(0.94,0.14,1.08),0.05), 15.0));
      /* coperta taupe che ricade sui lati: è il volume che la camera vede */
      res = opU(res, vec2(sdRoundBox(ep-vec3(0.00,0.04,0.18), vec3(0.98,0.155,0.78),0.08), 16.0));
      /* cuscino verso la finestra */
      res = opU(res, vec2(sdRoundBox(ep-vec3(0.02,0.18,-0.72), vec3(0.46,0.080,0.26),0.07), 19.0));
      res = opU(res, vec2(sdRoundBox(ep-vec3(0.,0.08,-1.12), vec3(0.96,0.22,0.05),0.03), 26.0));
    } else res.x = min(res.x, gb);
  }

  /* ---------------- mensole muro sinistro ---------------- */
  {
    float gb = max(p.x + 3.26, abs(p.z + 0.45) - 1.16);
    if(gb < GB){
      float sy = 0.88 + clamp(floor((p.y - 0.505)/0.75), 0.0, 2.0)*0.75;
      res = opU(res, vec2(sdRoundBox(p-vec3(-3.48,sy,-0.45), vec3(0.20,0.022,1.15),0.012), 25.0));
      res = opU(res, vec2(sdBox(p-vec3(-3.40,sy-0.038,-0.45), vec3(0.012,0.010,1.13)), 14.0));
      vec3 bq = vec3(p.x + 3.58, p.y - (sy-0.04), abs(p.z + 0.45) - 0.90);
      res = opU(res, vec2(sdBox(bq, vec3(0.045,0.050,0.040)), 25.0));
      res = opU(res, vec2(sdCapsule(vec3(p.x, p.y, abs(p.z+0.45)),
                                    vec3(-3.60, sy-0.16, 0.90), vec3(-3.34, sy-0.026, 0.90), 0.012), 25.0));

      /* mensola alta: attrezzatura tech */
      if(p.y > 2.28){
        float y = 2.38;
        res = opU(res, vec2(sdRoundBox(p-vec3(-3.42,y+0.12,-1.15), vec3(0.04,0.11,0.16),0.01), 42.0));
        res = opU(res, vec2(sdCylinder(p-vec3(-3.40,y+0.18,-0.55), 0.12, 0.018), 25.0));
        res = opU(res, vec2(sdSphere(p-vec3(-3.40,y+0.32,-0.55), 0.035), 42.0));
        res = opU(res, vec2(sdRoundBox(p-vec3(-3.40,y+0.07,0.05), vec3(0.08,0.06,0.10),0.015), 42.0));
        res = opU(res, vec2(sdRoundBox(p-vec3(-3.38,y+0.08,0.55), vec3(0.06,0.07,0.06),0.01), 26.0));
        res = opU(res, vec2(sdBox(p-vec3(-3.32,y+0.08,0.55), vec3(0.008,0.04,0.04)), 27.0));
        res = opU(res, vec2(sdRoundBox(p-vec3(-3.40,y+0.05,-0.05), vec3(0.10,0.035,0.07),0.012), 25.0));
      }

      /* mensola media: piante aliene + statuetta */
      if(p.y > 1.55 && p.y < 2.30){
        float y = 1.63;
        vec3 pot1 = vec3(-3.40, y+0.05, -1.20);
        res = opU(res, vec2(sdRoundBox(p-pot1, vec3(0.07,0.05,0.07),0.02), 26.0));
        {
          vec3 q = p - (pot1+vec3(0.,0.12,0.));
          float bulb = sdSphere(q, 0.09);
          float tend = sdCapsule(q, vec3(0.02,0.05,0.), vec3(0.12,0.18,0.05), 0.018);
          tend = min(tend, sdCapsule(q, vec3(-0.02,0.04,0.), vec3(-0.10,0.20,-0.04), 0.015));
          float leaf = min(sdSphere(q-vec3(0.08,0.16,0.04), 0.045),
                           sdSphere(q-vec3(-0.07,0.18,-0.03), 0.04));
          res = opU(res, vec2(smin(bulb, smin(tend, leaf, 0.03), 0.04), 40.0));
        }
        vec3 pot2 = vec3(-3.40, y+0.05, -0.35);
        res = opU(res, vec2(sdCylinder(p-pot2, 0.055, 0.065), 26.0));
        {
          vec3 q = p - (pot2+vec3(0.,0.08,0.));
          float stem = sdCapsule(q, vec3(0.), vec3(0.,0.28,0.), 0.02);
          float coil = sdTorus(q - vec3(0.0,0.10,0.0), vec2(0.078,0.030));
          coil = min(coil, sdTorus(q - vec3(0.0,0.18,0.0), vec2(0.055,0.026)));
          res = opU(res, vec2(smin(stem, coil, 0.03), 40.0));
        }
        /* cluster di cristalli organici */
        vec3 pot3 = vec3(-3.40, y+0.04, 0.25);
        res = opU(res, vec2(sdRoundBox(p-pot3, vec3(0.065,0.045,0.065),0.012), 26.0));
        {
          vec3 q = p - (pot3+vec3(0.,0.06,0.));
          float cr = sdRoundCone(q, 0.030, 0.004, 0.20);
          cr = min(cr, sdRoundCone(q - vec3(0.055,0.0,0.030), 0.022, 0.004, 0.13));
          cr = min(cr, sdRoundCone(q - vec3(-0.045,0.0,-0.035), 0.026, 0.004, 0.16));
          res = opU(res, vec2(cr, 40.0));
        }
        /* statuetta: creatura aliena su piedistallo */
        vec3 q = p - vec3(-3.40, y+0.03, 0.58);
        if(bnd(q, vec3(0.,0.14,0.), vec3(0.22,0.22,0.22)) < GB){
          float base = sdCylinder(q, 0.020, 0.075);
          vec3 t = q - vec3(0.0,0.135,0.0);
          float torso = sdRoundCone(t - vec3(0.,-0.10,0.), 0.055, 0.030, 0.17);
          float head = sdSphere(t - vec3(0.0,0.095,0.012), 0.042);
          float horn = min(sdCapsule(t, vec3( 0.026,0.115,0.0), vec3( 0.052,0.185,-0.02), 0.010),
                           sdCapsule(t, vec3(-0.026,0.115,0.0), vec3(-0.052,0.185,-0.02), 0.010));
          float arms = min(sdCapsule(t, vec3( 0.045,0.035,0.01), vec3( 0.115,0.095,0.03), 0.016),
                           sdCapsule(t, vec3(-0.045,0.035,0.01), vec3(-0.100,-0.045,0.04), 0.016));
          float body = smin(torso, head, 0.03);
          body = smin(body, arms, 0.02);
          body = smin(body, horn, 0.012);
          res = opU(res, vec2(min(base, body), 22.0));
        }
      }

      /* mensola bassa: armi */
      if(p.y < 1.58){
        float y = 0.88;
        vec3 wp = p - vec3(-3.38, y+0.06, -1.03);
        float rifle = sdCapsule(wp, vec3(0.,0.,-0.55), vec3(0.,0.,0.55), 0.022);
        rifle = min(rifle, sdRoundBox(wp-vec3(0.02,-0.02,-0.42), vec3(0.04,0.05,0.12),0.01));
        rifle = min(rifle, sdBox(wp-vec3(0.,0.04,0.15), vec3(0.015,0.03,0.04)));
        rifle = min(rifle, sdBox(wp-vec3(0.,-0.045,0.02), vec3(0.022,0.028,0.10)));
        res = opU(res, vec2(rifle, 41.0));

        vec3 gp = p - vec3(-3.38, y+0.05, -0.22);
        float gun = sdRoundBox(gp, vec3(0.035,0.04,0.12),0.012);
        gun = min(gun, sdRoundBox(gp-vec3(0.,-0.06,-0.02), vec3(0.03,0.055,0.04),0.01));
        res = opU(res, vec2(gun, 41.0));

        vec3 kp = p - vec3(-3.38, y+0.07, 0.32);
        float katana = sdCapsule(kp, vec3(0.,0.,-0.35), vec3(0.,0.,0.35), 0.012);
        katana = min(katana, sdCylinder(kp-vec3(0.,0.,-0.38), 0.04, 0.028));
        res = opU(res, vec2(katana, 41.0));
        res = opU(res, vec2(sdCapsule(kp, vec3(0.,0.,-0.32), vec3(0.,0.,0.32), 0.006), 27.0));
      }
    } else res.x = min(res.x, gb);
  }

  /* costolature verticali della parete sinistra */
  {
    float gb = max(p.x + 3.50, abs(p.z + 0.35) - 2.71);
    if(gb < GB){
      vec3 rbq = p - vec3(-3.555,1.66,0.0);
      rbq.z = mod(rbq.z + 0.24, 0.48) - 0.24;
      float rib = sdBox(rbq, vec3(0.048,1.24,0.042));
      rib = max(rib, sdBox(p - vec3(-3.555,1.66,-0.35), vec3(0.10,1.24,2.70)));
      res = opU(res, vec2(rib, 26.0));
    } else res.x = min(res.x, gb);
  }

  /* ---------------- mensole muro destro + casse ---------------- */
  {
    float gb = max(3.43 - p.x, abs(p.z + 0.70) - 1.08);
    if(gb < GB){
      float sy = 0.88 + clamp(floor((p.y - 0.505)/0.75), 0.0, 2.0)*0.75;
      res = opU(res, vec2(sdRoundBox(p-vec3(3.55,sy,-0.70), vec3(0.12,0.018,1.05),0.01), 25.0));
      res = opU(res, vec2(sdBox(p-vec3(3.47,sy-0.032,-0.70), vec3(0.010,0.008,1.03)), 14.0));
      vec3 bq = vec3(p.x - 3.62, p.y - (sy-0.03), abs(p.z + 0.70) - 0.80);
      res = opU(res, vec2(sdBox(bq, vec3(0.032,0.042,0.032)), 25.0));
    } else res.x = min(res.x, gb);
  }
  {
    float gb = max(2.97 - p.x, 1.50 - p.z);
    if(gb < GB){
      res = opU(res, vec2(sdRoundBox(p-vec3(3.30,0.20,1.95), vec3(0.30,0.20,0.42),0.03), 23.0));
      res = opU(res, vec2(sdRoundBox(p-vec3(3.30,0.56,2.05), vec3(0.26,0.16,0.34),0.03), 23.0));
      res = opU(res, vec2(sdBox(p-vec3(2.99,0.20,1.95), vec3(0.008,0.05,0.30)), 27.0));
      res = opU(res, vec2(sdBox(p-vec3(3.30,0.735,2.05), vec3(0.20,0.018,0.26)), 5.0));
    } else res.x = min(res.x, gb);
  }

  /* social orbs: bounding box unico, poi le 7 sfere */
  {
    float gb = max(3.09 - p.x, abs(p.z + 0.70) - 0.92);
    if(gb < GB){
      for(int i=0;i<7;i++) res = opU(res, vec2(sdSphere(p-socialPos(i), 0.090), 30.0+float(i)));
    } else res.x = min(res.x, gb);
  }

  /* ---------------- parete di fondo: portello di servizio ---------------- */
  {
    float gb = 2.66 - p.z;
    if(gb < GB){
      /* montanti bulkhead */
      res = opU(res, vec2(sdBox(vec3(abs(p.x)-1.60, p.y-1.60, p.z-2.86), vec3(0.06,1.26,0.05)), 26.0));
      /* telaio del portello + due battenti con giunto centrale */
      vec3 dq = p - vec3(0.0,1.36,2.78);
      float frame = sdBox(dq, vec3(1.10,1.38,0.10));
      frame = max(frame, -sdBox(dq - vec3(0.0,0.0,-0.05), vec3(0.94,1.24,0.12)));
      res = opU(res, vec2(frame, 26.0));
      float leaf = sdRoundBox(vec3(abs(dq.x)-0.475, dq.y, dq.z+0.035), vec3(0.455,1.22,0.045), 0.015);
      res = opU(res, vec2(leaf, 5.0));
      res = opU(res, vec2(sdBox(dq - vec3(0.0,-1.16,-0.06), vec3(0.92,0.075,0.030)), 26.0));
      res = opU(res, vec2(sdCapsule(p, vec3(-0.075,1.55,2.69), vec3(-0.075,1.24,2.69), 0.022), 25.0));
      res = opU(res, vec2(sdBox(dq - vec3(0.0,0.0,-0.075), vec3(0.010,1.20,0.008)), 27.0));
      /* cerniere: barilotti verticali ripetuti sui due stipiti */
      vec3 hg = vec3(abs(p.x)-0.99, mod(p.y-0.30,0.86)-0.43, p.z-2.71);
      float hinge = max(sdCylinder(hg, 0.070, 0.032),
                        sdBox(p - vec3(0.0,1.36,2.71), vec3(1.05,1.20,0.10)));
      res = opU(res, vec2(hinge, 25.0));
      /* pannello di stato spento + targhetta */
      res = opU(res, vec2(sdRoundBox(p-vec3(-1.95,2.05,2.84), vec3(0.42,0.26,0.05),0.02), 28.0));
      res = opU(res, vec2(sdBox(p-vec3(-1.95,2.05,2.79), vec3(0.36,0.20,0.01)), 27.0));
      res = opU(res, vec2(sdRoundBox(p-vec3(1.95,1.95,2.85), vec3(0.30,0.10,0.03),0.01), 26.0));
      /* montante di tubi verticali con staffe */
      float py = mod(p.y + 0.30, 0.60) - 0.30;
      float pipes = sdCapsule(p, vec3(2.42,0.10,2.78), vec3(2.42,2.84,2.78), 0.048);
      pipes = min(pipes, sdCapsule(p, vec3(2.56,0.10,2.76), vec3(2.56,2.84,2.76), 0.032));
      float br = sdBox(vec3(p.x-2.49, py, p.z-2.86), vec3(0.115,0.020,0.085));
      pipes = min(pipes, max(br, sdBox(p-vec3(2.49,1.47,2.80), vec3(0.20,1.37,0.14))));
      res = opU(res, vec2(pipes, 21.0));
    } else res.x = min(res.x, gb);
  }

  /* armadietto di stivaggio nell'angolo di fondo */
  {
    float gb = max(2.04 - p.z, abs(p.x + 2.86) - 0.63);
    if(gb < GB){
      vec3 lq = p - vec3(-2.86,0.55,2.42);
      float body = sdRoundBox(lq, vec3(0.62,0.55,0.34), 0.02);
      body = max(body, -sdBox(vec3(abs(lq.x)-0.31, lq.y, lq.z+0.34), vec3(0.005,0.50,0.02)));
      body = max(body, -sdBox(lq - vec3(0.0,0.0,-0.34), vec3(0.60,0.008,0.02)));
      res = opU(res, vec2(body, 26.0));
      res = opU(res, vec2(sdCapsule(p, vec3(-3.14,0.62,2.06), vec3(-2.90,0.62,2.06), 0.018), 25.0));
      res = opU(res, vec2(sdCapsule(p, vec3(-2.82,0.62,2.06), vec3(-2.58,0.62,2.06), 0.018), 25.0));
      vec3 vq = lq - vec3(0.0,0.42,-0.34);
      vq.x = mod(vq.x + 0.045, 0.09) - 0.045;
      float vent = sdBox(vq, vec3(0.028,0.055,0.012));
      vent = max(vent, sdBox(lq - vec3(0.0,0.42,-0.34), vec3(0.34,0.06,0.03)));
      res = opU(res, vec2(vent, 5.0));
      res = opU(res, vec2(sdBox(lq - vec3(0.0,0.565,0.0), vec3(0.58,0.012,0.30)), 5.0));
    } else res.x = min(res.x, gb);
  }

  /* piastra d'ispezione nel pavimento */
  {
    float gb = bnd(p, vec3(0.55,0.02,-2.55), vec3(0.56,0.12,0.56));
    if(gb < GB){
      vec3 hq = p - vec3(0.55,0.008,-2.55);
      float plate = sdCylinder(hq, 0.012, 0.46);
      plate = max(plate, -sdCylinder(hq - vec3(0.,0.008,0.), 0.010, 0.40));
      res = opU(res, vec2(min(plate, sdCylinder(hq, 0.008, 0.41)), 29.0));
      res = opU(res, vec2(sdTorus(hq - vec3(0.,0.012,0.), vec2(0.16,0.012)), 25.0));
    } else res.x = min(res.x, gb);
  }

  return res;
}

/* Mappa ridotta per i raggi d'ombra: solo i volumi che occludono davvero la
   luce della finestra, approssimati con box. I props, i dettagli di soffitto
   (che la luce radente della finestra non raggiunge) e le minuterie sono
   esclusi: un raggio d'ombra costa così una frazione di map(). */
float mapShadow(vec3 p){
  vec3 rq = p - ROOM_C;
  float d = max(sdBox(rq, ROOM_IH + vec3(0.32)),
               -sdChamferBox(rq, ROOM_IH, CH_VERT, CH_TOP, CH_BOT));
  vec2 wl = p.xy - WIN_C.xy;
  d = max(d, -max(sdOctRect(wl, WIN_B, WIN_CH), abs(p.z - WIN_C.z) - 0.9));

  float gb = bnd(p, vec3(0.0,0.45,0.85), vec3(1.82,0.60,0.82));
  if(gb < 0.12){
    vec3 dp = p - DESK_C;
    d = min(d, sdBox(dp, vec3(1.55,0.042,0.55)));
    d = min(d, sdBox(vec3(abs(dp.x)-1.12, dp.y+0.395, dp.z+0.04), vec3(0.22,0.36,0.38)));
  } else d = min(d, gb);

  gb = max(1.58 - p.x, abs(p.z + 1.64) - 1.16);
  if(gb < 0.12){
    d = min(d, sdBox((p - BED_C) - vec3(0.0,-0.16,0.0), vec3(0.90,0.14,1.08)));
  } else d = min(d, gb);

  gb = max(p.x + 3.26, abs(p.z + 0.45) - 1.16);
  if(gb < 0.12){
    float sy = mod(p.y - 0.505, 0.75) - 0.375;
    d = min(d, max(sdBox(vec3(p.x+3.48, sy, p.z+0.45), vec3(0.20,0.030,1.15)),
                   abs(p.y-1.63)-0.80));
  } else d = min(d, gb);

  gb = max(3.43 - p.x, abs(p.z + 0.70) - 1.08);
  if(gb < 0.12){
    float sy = mod(p.y - 0.505, 0.75) - 0.375;
    d = min(d, max(sdBox(vec3(p.x-3.55, sy, p.z+0.70), vec3(0.12,0.026,1.05)),
                   abs(p.y-1.63)-0.80));
  } else d = min(d, gb);

  gb = max(2.97 - p.x, 1.50 - p.z);
  if(gb < 0.12) d = min(d, sdBox(p - vec3(3.30,0.36,2.00), vec3(0.30,0.40,0.45)));
  else d = min(d, gb);

  gb = max(2.04 - p.z, abs(p.x + 2.86) - 0.63);
  if(gb < 0.12) d = min(d, sdBox(p - vec3(-2.86,0.55,2.42), vec3(0.62,0.55,0.34)));
  else d = min(d, gb);

  if(p.z < -3.15) d = min(d, sdBox(p - vec3(0.0,0.665,-3.545), vec3(3.05,0.055,0.145)));
  return d;
}

/* ---------- march / normali / AO / ombre ---------- */
vec2 march(vec3 ro, vec3 rd){
  float t=0.0, m=-1.0;
  /* soglia proporzionale a t: ~un pixel di footprint, oltre non si vede */
  for(int i=0;i<64;i++){
    vec2 h = map(ro+rd*t);
    if(h.x < 0.0011*t+0.0006){ m=h.y; break; }
    t += h.x;
    if(t>18.0){ m=-1.0; break; }
  }
  if(t>18.0) m=-1.0;
  return vec2(t,m);
}
/* normale a 4 tap (tetraedro): due map() in meno del gradiente centrale */
vec3 calcNormal(vec3 p){
  const vec2 k = vec2(1.0,-1.0);
  const float e = 0.0022;
  return normalize(k.xyy*map(p + k.xyy*e).x +
                   k.yyx*map(p + k.yyx*e).x +
                   k.yxy*map(p + k.yxy*e).x +
                   k.xxx*map(p + k.xxx*e).x);
}
float calcAO(vec3 p, vec3 n){
  float occ=0., sca=1.;
  for(int i=1;i<=2;i++){
    float h=0.04+0.14*float(i)/2.0;
    occ += (h-mapShadow(p+n*h))*sca;
    sca *= 0.65;
  }
  return clamp(1.0-2.6*occ,0.,1.);
}
float softShadow(vec3 ro, vec3 rd){
  float res=1.0, t=0.05;
  for(int i=0;i<7;i++){
    float h=mapShadow(ro+rd*t);
    res=min(res,9.0*h/t);
    t+=clamp(h,0.11,0.9);
    if(res<0.04||t>5.0) break;
  }
  return clamp(res,0.,1.);
}

/* ============================================================
   ESTERNO: cielo di Encelado, Saturno, città
   ============================================================ */
float ringProfile(float r){
  if(r < 0.46 || r > 1.17) return 0.0;
  float d = 1.0;
  d *= 1.0 - 0.80*smoothstep(0.595,0.615,r)*smoothstep(0.665,0.645,r);
  d *= 1.0 - 0.92*smoothstep(0.735,0.752,r)*smoothstep(0.805,0.788,r);
  d *= 1.0 - 0.50*smoothstep(0.900,0.914,r)*smoothstep(0.950,0.936,r);
  float fine = 0.70 + 0.20*sin(r*88.0) + 0.14*sin(r*37.0+1.3);
  return d*fine*smoothstep(0.46,0.50,r)*smoothstep(1.17,1.07,r);
}

/* versione economica usata nei riflessi: solo gradiente di cielo,
   alone di Saturno e bagliore della città all'orizzonte */
vec3 skyLite(vec3 rd){
  vec3 col = mix(vec3(0.008,0.011,0.024), vec3(0.018,0.026,0.052), clamp(rd.y*0.5+0.5,0.,1.));
  float ang = acos(clamp(dot(rd,SAT_DIR),-1.,1.));
  col += vec3(0.30,0.27,0.23)*exp(-ang*ang*90.0)*0.55;
  col += vec3(0.045,0.075,0.135)*smoothstep(0.10,-0.10,rd.y)*smoothstep(0.2,-0.4,rd.z);
  return col;
}

vec3 renderCity(vec3 ro, vec3 rd){
  float t = iTime;
  vec3 fogCol = vec3(0.042,0.058,0.098);

  /* A. cielo notte + nebulose */
  vec3 col = mix(vec3(0.009,0.013,0.028), vec3(0.021,0.031,0.066), clamp(rd.y*0.5+0.5,0.,1.));
  {
    vec3 n1 = normalize(vec3(0.35,0.55,-0.7));
    vec3 n2 = normalize(vec3(-0.55,0.25,-0.6));
    col += vec3(0.20,0.07,0.30)*exp(-dot(rd-n1,rd-n1)*15.0)*0.13;
    col += vec3(0.04,0.15,0.32)*exp(-dot(rd-n2,rd-n2)*20.0)*0.11;
  }

  /* B. Saturno con anelli e ombra sul piano */
  float satDisk = 0.0;
  vec3 sunDir = normalize(vec3(-0.55,0.30,-0.78));
  {
    float ca = dot(rd,SAT_DIR);
    float ang = acos(clamp(ca,-1.,1.));
    float diskR = 0.104;

    vec3 rx = normalize(cross(SAT_DIR, vec3(0.,1.,0.)));
    vec3 ry = normalize(cross(SAT_DIR, rx));
    vec3 v = rd - SAT_DIR*ca;
    vec2 e = vec2(dot(v,rx)/0.235, dot(v,ry)/0.050);
    float rr = length(e);
    float ringA = ringProfile(rr);
    float isFront = step(e.y, 0.0);
    float shadow = 1.0 - 0.78*smoothstep(0.42,0.16,abs(e.x+0.30))*step(0.0,e.y);
    vec3 ringCol = mix(vec3(0.24,0.21,0.19), vec3(0.60,0.55,0.46), ringA)*shadow;

    if(isFront < 0.5 && ang > diskR+0.001) col += ringCol*ringA*0.90;

    satDisk = smoothstep(diskR+0.004, diskR-0.002, ang);
    col += vec3(0.34,0.30,0.26)*exp(-ang*ang*260.0)*0.13;
    if(satDisk>0.001){
      float lat = (rd.y-SAT_DIR.y)*9.2;
      float band = 0.42*sin(lat*13.0) + 0.28*sin(lat*22.0+0.7)
                 + 0.18*sin(lat*33.0+2.1) + 0.12*sin(lat*54.0);
      band = 0.5+0.5*band;
      vec3 sc = mix(vec3(0.32,0.28,0.24), vec3(0.72,0.65,0.53), band);
      sc = mix(sc, vec3(0.42,0.38,0.35), smoothstep(0.45,0.95,abs(rd.y-SAT_DIR.y)*11.0));
      float lambert = clamp(dot(normalize((rd-SAT_DIR)*8.0 + SAT_DIR*0.35), sunDir)*0.5+0.62, 0.0, 1.0);
      float limb = smoothstep(0.0,0.020,diskR-ang);
      col = mix(col, sc*lambert*limb, satDisk);
    }
    if(isFront > 0.5) col += ringCol*ringA*1.00;
  }

  /* stelle */
  if(rd.y>0.04 && satDisk<0.5){
    vec2 sph = vec2(atan(rd.x,-rd.z), asin(clamp(rd.y,-1.,1.)));
    vec2 sg = sph*220.0;
    vec2 sid = floor(sg);
    float sh = hash21(sid);
    if(sh>0.972){
      vec2 sf = fract(sg)-0.5;
      float st = smoothstep(0.22,0.0,length(sf));
      float tw = 0.55+0.45*sin(t*1.6+sh*90.0);
      col += vec3(0.70,0.80,0.98)*st*tw*smoothstep(0.04,0.38,rd.y)*(sh-0.972)*22.0;
    }
  }

  float hitT = 1e5;
  vec3 stationPos = vec3(32.5, 19.5, -110.0);

  /* C. landa di ghiaccio */
  if(rd.y<-0.02){
    float tg = (-2.2-ro.y)/rd.y;
    if(tg>0.){
      vec3 gp = ro+rd*tg;
      float crack = max(
        smoothstep(0.05,0.0,abs(fract(gp.x*0.18+gp.z*0.07)-0.5)-0.47),
        smoothstep(0.04,0.0,abs(fract(gp.z*0.22-gp.x*0.05)-0.5)-0.47)
      );
      float crack2 = smoothstep(0.03,0.0,abs(fract(gp.x*0.55)-0.5)-0.48)
                   * smoothstep(0.5,0.0,abs(fract(gp.z*0.4)-0.5));
      vec3 gc = vec3(0.075,0.090,0.130);
      gc = mix(gc, vec3(0.035,0.050,0.080), crack*0.75);
      gc += vec3(0.11,0.17,0.24)*crack2*0.35;
      vec3 nApprox = normalize(vec3(crack*0.4-0.2, 1.0, crack2*0.3));
      gc += vec3(0.38,0.36,0.32)*pow(max(dot(nApprox, SAT_DIR),0.0), 8.0)*0.22;
      col = mix(gc, fogCol, 1.0-exp(-tg*0.025));
      hitT = tg;
    }
  }

  /* creste di ghiaccio */
  if(rd.z < -0.02){
    for(int ri=0;ri<2;ri++){
      float rz = ri==0 ? -42.0 : -68.0;
      float tr = (rz-ro.z)/rd.z;
      if(tr<0. || tr>=hitT) continue;
      vec3 rp = ro+rd*tr;
      float h = 0.35 + 0.55*hash21(vec2(floor(rp.x*0.12), float(ri)))
              + 0.7*sin(rp.x*0.07+float(ri)) + 0.35*sin(rp.x*0.19*1.7);
      h *= 1.0 - 0.2*float(ri);
      if(rp.y < h && rp.y > -3.0){
        float slope = smoothstep(h, h-0.9, rp.y);
        vec3 rc = mix(vec3(0.062,0.078,0.115), vec3(0.130,0.148,0.185), slope);
        float crev = smoothstep(0.04,0.0,abs(fract(rp.x*0.35)-0.5)-0.46);
        rc = mix(rc, vec3(0.028,0.042,0.068), crev*0.7);
        col = mix(rc, fogCol, 1.0-exp(-tr*0.022));
        hitT = tr;
        break;
      }
    }
  }

  /* pennacchi criovolcanici */
  if(hitT>55.0 && rd.z<-0.05){
    float tp2 = (-78.0-ro.z)/rd.z;
    if(tp2>0.){
      vec3 pp = ro+rd*tp2;
      for(int i=0;i<3;i++){
        float px = float(i)*42.0-40.0;
        float g = exp(-pow((pp.x-px)*0.04,2.0));
        float vfade = smoothstep(40.0,3.0,pp.y)*smoothstep(-2.0,6.0,pp.y);
        col += vec3(0.32,0.48,0.72)*g*vfade*0.13*(0.75+0.25*sin(t*0.55+float(i)*2.4));
      }
    }
  }

  /* D. stazione orbitale */
  if(rd.z < -0.01 && rd.y > -0.02){
    float ts = (stationPos.z-ro.z)/rd.z;
    if(ts>0.0 && ts<hitT){
      vec3 sp = ro+rd*ts;
      vec2 uv = (sp.xy - stationPos.xy) * 0.085;
      if(length(uv) < 2.2){
        vec2 a = abs(uv);
        float hub = max(a.x-0.28, a.y-0.20);
        hub = max(hub, max(a.x*0.6+a.y*0.35, a.y)-0.26);
        float spine = max(a.x-0.06, a.y-0.70);
        float arm = max(abs(uv.y)-0.05, abs(abs(uv.x)-0.55)-0.22);
        float panel = max(abs(uv.y)-0.14, abs(abs(uv.x)-1.15)-0.48);
        float strut = max(abs(uv.y)-0.025, abs(abs(uv.x)-0.70)-0.12);
        float body = min(min(hub, spine), min(arm, min(panel, strut)));
        float mask = smoothstep(0.035, -0.01, body);
        if(mask > 0.01){
          float litWin = step(0.55, hash21(floor(uv*14.0)))
                       * smoothstep(0.08,0.0,hub+0.02)
                       * (0.55+0.45*sin(t*1.8+uv.x*6.0));
          float panelLine = smoothstep(0.02,0.0,abs(fract(uv.x*3.5)-0.5)-0.42)
                          * smoothstep(0.05,0.0,panel);
          vec3 sc = vec3(0.17,0.20,0.25)*mask;
          sc += vec3(0.28,0.60,0.86)*litWin*0.75;
          sc += vec3(0.12,0.20,0.32)*panelLine*mask;
          sc += vec3(0.40,0.70,0.90)*smoothstep(0.06,0.0,abs(spine+0.02))*0.28*(0.6+0.4*sin(t*3.0));
          col = mix(col, mix(sc, fogCol, (1.0-exp(-ts*0.010))*0.35), clamp(mask,0.,1.));
        }
      }
    }
  }

  /* E. metropoli */
  if(rd.z < -0.02 && rd.y < 0.12){
    for(int i=0;i<3;i++){
      float fi = float(i);
      float lz = -(28.0 + fi*20.0);
      float tt = (lz-ro.z)/rd.z;
      if(tt<0. || tt>hitT) continue;
      vec3 p = ro + rd*tt;

      float sideClear = smoothstep(-10.0,-2.0,p.x);
      float bw = 2.4 + fi*2.4;
      float xx = p.x/bw + fi*5.17;
      float id = floor(xx);
      float fx = fract(xx);
      float hh = hash21(vec2(id,fi));
      float gap = step(0.45, hash21(vec2(id*3.1, fi+9.0))*sideClear);
      float bh = (0.55 + hh*hh*3.8 + fi*0.65)*gap;
      bh = min(bh, 4.2 - fi*0.35);
      if(bh < 0.15) continue;

      float typ = floor(hash21(vec2(id*1.7, fi*4.2))*4.0);
      float silhouette;
      if(typ < 0.5){
        silhouette = step(p.y, bh)*step(-2.5, p.y);
      } else if(typ < 1.5){
        float setBh = bh * (1.0 - 0.28*step(0.5, abs(fx-0.5)*2.0));
        if(p.y > bh*0.55) setBh = bh * (0.55 + 0.20*step(0.35,fx)*step(fx,0.65));
        silhouette = step(p.y, setBh)*step(-2.5, p.y);
      } else if(typ < 2.5){
        silhouette = step(p.y, bh*max(0.0, 1.0 - abs(fx-0.5)*1.7))*step(-2.5, p.y);
      } else {
        silhouette = step(0.16, abs(fx-0.5))*step(p.y, bh)*step(-2.5, p.y);
      }

      float bridge = 0.0;
      if(fi>0.5 && fi<2.5 && hash21(vec2(id,fi+40.0))>0.94){
        float by = 1.2 + hh*1.5;
        bridge = step(abs(p.y-by),0.08)*step(abs(fx-0.5),0.55)*step(by, bh);
      }

      float edge = smoothstep(0.02,0.08,fx)*smoothstep(0.98,0.92,fx);
      if((silhouette>0.5 && edge>0.5) || bridge>0.5){
        hitT = tt;
        vec3 base = vec3(0.022,0.030,0.055)*(1.0+fi*0.45);
        vec2 wuv = vec2(p.x/0.28, p.y/0.18);
        vec2 wid = floor(wuv);
        vec2 wf  = fract(wuv);
        float lit = step(hash21(wid+id*0.37), 0.34);
        float wm  = step(0.26,wf.x)*step(wf.x,0.74)*step(0.20,wf.y)*step(wf.y,0.80);
        float wh = hash21(wid*1.71+3.0);
        vec3 wc = wh<0.42 ? vec3(0.28,0.40,0.92) :
                  wh<0.74 ? vec3(0.12,0.62,0.92) :
                  wh<0.92 ? vec3(0.60,0.76,0.95) : vec3(0.62,0.34,0.88);
        vec3 c = base + wc*lit*wm*(0.80+0.20*sin(t*2.5+hash21(wid)*40.0))*1.10;
        c += base*bridge*2.0 + vec3(0.15,0.38,0.62)*bridge*0.6;

        if(typ > 0.5){
          c += vec3(0.45,0.66,0.85)*smoothstep(0.18,0.0,abs(p.y-bh+0.06))
               *step(abs(fx-0.5),0.06)*(0.5+0.5*sin(t*3.0+id));
        } else {
          c += vec3(0.70,0.20,0.42)*smoothstep(0.14,0.0,abs(p.y-bh+0.08))
               *step(0.70,hash21(vec2(id,5.0)))*(0.5+0.5*sin(t*2.5+id*3.0));
        }

        if(hash21(vec2(id,33.0+fi))>0.86 && bh>2.2){
          vec2 suv = (p.xy - vec2((id-fi*5.17+0.5)*bw, bh*0.55))/vec2(bw*0.28, 0.7);
          float sgn = step(abs(suv.x),1.0)*step(abs(suv.y),1.0);
          float sflick = step(0.12, fract(sin(floor(t*8.0)*12.9+id)*43.75));
          float sh2 = hash21(vec2(id,2.0));
          vec3 scol = sh2<0.50 ? vec3(0.16,0.62,0.85) :
                      sh2<0.80 ? vec3(0.48,0.28,0.80) : vec3(0.75,0.44,0.22);
          c += scol*sgn*sflick*(0.55+0.45*sin(suv.y*18.0+suv.x*5.0+t))*1.35;
        }
        col = mix(c, fogCol, 1.0-exp(-tt*0.022));
        break;
      }
    }
  }

  /* navi in transito */
  if(rd.z<-0.01){
    for(int i=0;i<4;i++){
      float fi = float(i);
      float seed = hash11(fi*13.7);
      float phase = fract(t*(0.07 + seed*0.10) + seed);
      float ease = smoothstep(0.0,1.0,phase);
      vec3 dest = vec3(
        stationPos.x + mix(-20.0, 3.0, hash11(fi*3.1)) - phase*9.0,
        mix(stationPos.y - 1.5, 2.5 + hash11(fi*5.5)*4.5, ease),
        mix(stationPos.z + 2.0, -32.0 - fi*5.0, ease)
      );
      float lift = 1.2 + seed*1.2;
      vec3 sp = mix(stationPos, dest, ease) + vec3(0., lift*sin(phase*PI), 0.);
      vec3 vel = dest - stationPos;
      vel.y += lift*PI*cos(phase*PI)*0.12;
      float vlen = length(vel);
      if(vlen < 1e-4) continue;
      vec3 fw = vel/vlen;
      vec3 rt = normalize(cross(fw, vec3(0.,1.,0.)));
      if(length(cross(fw, vec3(0.,1.,0.))) < 0.08) rt = normalize(cross(fw, vec3(1.,0.,0.)));
      vec3 upv = cross(rt, fw);

      float dist = length(sp-ro);
      vec3 dShip = (sp-ro)/dist;
      float scl = 0.55 + seed*0.25;
      if(acos(clamp(dot(rd,dShip),-1.,1.)) > 2.2*scl/dist) continue;
      float tp = dist / max(dot(rd,dShip), 0.2);
      if(tp<0.0 || tp>hitT) continue;
      vec3 q = (ro + rd*tp) - sp;
      float along = dot(q, fw)/scl;
      float side  = dot(q, rt)/scl;
      float vert  = dot(q, upv)/scl;

      float halfL = 0.85;
      float fuseW = 0.13 * (1.0 - abs(along)/halfL);
      float fuse = max(max(abs(along)-halfL, abs(side)-fuseW), abs(vert)-0.08);
      float wingSpan = 0.55 * clamp(1.0 - (along+0.15)/0.7, 0.0, 1.0);
      float wing = max(max(abs(along+0.05)-0.35, abs(side)-wingSpan), abs(vert)-0.03);
      float fin = max(max(abs(along+0.55)-0.18, abs(side)-0.04),
                      abs(vert)-0.16*(1.0-abs(along+0.55)/0.18));

      float mask = smoothstep(0.04, -0.01, min(fuse, min(wing, fin)));
      if(mask < 0.01) continue;

      vec3 hue = mix(vec3(0.42,0.48,0.58), vec3(0.26,0.30,0.38), seed)*mask;
      hue += vec3(0.18,0.42,0.68)*smoothstep(0.12,0.0, length(vec2(along-0.25, side)*vec2(1.4,2.2)))
             *step(abs(vert),0.1)*0.7;
      vec3 exhaust = mix(vec3(0.30,0.68,0.85), vec3(0.85,0.45,0.20), step(0.75,seed));
      hue += exhaust*smoothstep(0.22,0.0, length(vec2(along+0.78, side)*vec2(1.6,2.5)))
             *step(along, -0.55)*(0.9+0.35*sin(t*20.0+fi*5.0));
      for(int k=1;k<=2;k++){
        float fk = float(k);
        vec3 dt = normalize((sp - fw*scl*(0.5+fk*0.55))-ro);
        float dang = 1.0-dot(rd,dt);
        hue += exhaust * 0.000008/(0.000002+dang*dang*8.0) * (1.0-fk*0.28);
      }
      col += hue;
    }
  }

  return col;
}

/* ============================================================
   UI DEL TABLET
   ============================================================ */
vec3 tabletUI(vec2 uv, float hover, float focus){
  float t=iTime;
  vec3 c = vec3(0.015,0.008,0.05);
  float hd = step(0.68,uv.y);
  c += vec3(0.45,0.2,1.0)*hd*(0.55+0.1*sin(t*2.0));
  c += vec3(1.0)*hd*step(abs(uv.y-0.82),0.035)*step(uv.x,-0.15)*step(-0.85,uv.x)*0.7;
  float av = length((uv-vec2(-0.62,0.22))*vec2(1.0,1.35))-0.20;
  c += vec3(0.15,0.65,1.0)*smoothstep(0.03,-0.01,av)*0.85;
  c += vec3(0.3,0.75,1.0)*smoothstep(0.10,0.0,abs(av))*0.5;
  for(int i=0;i<5;i++){
    float fi=float(i);
    float y0 = 0.30-fi*0.20;
    float len = 0.45+0.5*hash11(fi*3.7);
    float typing = clamp(t*0.7-fi*0.5,0.0,1.0);
    float ln = step(abs(uv.y-y0),0.045)*step(uv.x,-0.25+len*typing)*step(-0.28,uv.x);
    c += mix(vec3(0.55,0.5,1.0),vec3(0.3,0.8,1.0),hash11(fi*9.0))*ln*0.55;
  }
  float ic = length(uv-vec2(-0.62,-0.55))-0.11;
  c += vec3(0.9,0.3,1.0)*smoothstep(0.05,0.0,abs(ic))*(0.6+0.4*sin(t*3.0));
  c += vec3(1.0)*step(abs(uv.x-0.62),0.02)*step(abs(uv.y+0.55),0.05)*step(0.5,fract(t*1.2));
  c *= 0.9+0.1*sin(uv.y*90.0);
  c *= 1.0 + hover*0.9;

  if(focus>0.5){
    for(int i=0;i<5;i++){
      float fi=float(i);
      float y0 = 0.30-fi*0.20;
      float len = 0.45+0.5*hash11(fi*3.7);
      float typing = clamp(fract(t*0.55-fi*0.18)*1.35,0.0,1.0);
      float ln = step(abs(uv.y-y0),0.045)*step(uv.x,-0.25+len*typing)*step(-0.28,uv.x);
      c += vec3(0.3,0.9,1.0)*ln*0.25;
    }
    c *= 0.75+0.45*(0.55+0.45*sin(uv.y*70.0 - t*14.0));
    float hx = abs(fract(uv.x*9.0)-0.5);
    float hy = abs(fract(uv.y*14.0+t*0.4)-0.5);
    c += vec3(0.2,0.85,1.0)*smoothstep(0.48,0.42,max(hx*1.2,hy))*0.18;
    float ang = atan(uv.y+0.05, uv.x+0.15);
    float rad = length(uv-vec2(-0.15,-0.05));
    float sweep = smoothstep(0.12,0.0,abs(fract(ang/6.2831853 - t*0.45)-0.5)-0.42);
    c += vec3(0.35,0.9,1.0)*sweep*smoothstep(0.55,0.15,rad)*0.55;
    float cl = floor((uv.x+1.0)*8.0);
    float rain = fract(uv.y*4.0 + t*1.8 + hash11(cl*7.3)*4.0);
    c += vec3(0.25,1.0,0.75)*step(0.82,rain)*step(abs(uv.x),0.95)*step(uv.y,-0.75)*0.45;
    c += vec3(0.7,0.35,1.0)*step(0.88,abs(uv.x))*step(0.82,abs(uv.y))*(0.5+0.5*sin(t*6.0));
    float glitch = step(0.97,hash11(floor(t*18.0))) * step(0.4,hash21(floor(uv*vec2(40.0,12.0))+vec2(floor(t*18.0))));
    c = mix(c, vec3(c.b,c.g,c.r)*vec3(1.2,0.6,1.4), glitch*0.65);
    c *= 1.15+0.2*sin(t*5.0);
  }
  return c;
}

/* ============================================================
   MATERIALI
   ============================================================ */
/* struttura dello shell: pareti in piastre metalliche, pavimento in
   grafite lucida, soffitto a pannelli */
void shellMaterial(vec3 pos, vec3 n, out vec3 alb, out float gloss, out vec3 emis, out vec3 nOut){
  alb = vec3(0.05); gloss = 0.2; emis = vec3(0.0); nOut = n;

  float bevelTop  = smoothstep(0.30,0.55,-n.y) * smoothstep(0.95,0.80,-n.y);
  float bevelVert = smoothstep(0.35,0.55,abs(n.x)) * smoothstep(0.35,0.55,abs(n.z));

  if(n.y > 0.80){
    /* --- pavimento: lastroni di grafite, umidi a chiazze --- */
    vec2 tile = pos.xz/1.42;
    vec2 tf = abs(fract(tile)-0.5);
    float seam = smoothstep(0.485,0.5,max(tf.x,tf.y));
    float bevel = smoothstep(0.44,0.5,max(tf.x,tf.y));

    vec3 w = vnoiseD(pos.xz*0.85 + 4.0);
    float grime = fbm2(pos.xz*1.7);

    alb = mix(vec3(0.055,0.060,0.072), vec3(0.082,0.088,0.100), grime);
    alb = mix(alb, vec3(0.018,0.020,0.028), seam*0.9);
    alb *= 0.86 + 0.14*bevel;

    vec2 hx = pos.xz*7.0;
    float hexg = max(abs(hx.x*0.8660254 + hx.y*0.5), abs(hx.y));
    alb += vec3(0.010,0.014,0.018)*smoothstep(0.42,0.5,abs(fract(hexg)-0.5));

    gloss = mix(0.58, 0.94, smoothstep(0.30,0.72,w.x));
    nOut = normalize(n + vec3(-w.y, 0.0, -w.z)*0.40);

    emis += vec3(0.06,0.18,0.30)*seam*0.10;
    float lane = smoothstep(0.42,0.36,abs(pos.x)) * step(-2.6,pos.z) * step(pos.z,2.4);
    alb = mix(alb, vec3(0.078,0.084,0.098), lane*0.7);
    emis += vec3(0.08,0.20,0.30)*lane*smoothstep(0.5,0.46,abs(fract(pos.z*0.9)-0.5))*0.28;
    float frost = smoothstep(-2.9,-3.6,pos.z);
    alb += vec3(0.040,0.058,0.080)*frost*0.55;
    gloss = mix(gloss, 0.42, frost*0.6);
  }
  else if(n.y < -0.80){
    /* --- soffitto: pannelli di servizio --- */
    alb = vec3(0.048,0.052,0.062);
    gloss = 0.12;
    vec2 pan = abs(fract(pos.xz/0.92)-0.5);
    float pseam = smoothstep(0.455,0.5,max(pan.x,pan.y));
    alb = mix(alb, vec3(0.022,0.024,0.032), pseam*0.85);
    alb *= 0.9 + 0.2*fbm2(pos.xz*2.3);

    float xs = abs(pos.x - pos.z*0.098);
    float run = step(-3.24, pos.z)*step(pos.z, 2.02);
    float halo = smoothstep(0.62,0.14,abs(xs-1.88))*run;
    alb = mix(alb, vec3(0.028,0.032,0.042), halo*0.55);
    emis += vec3(0.22,0.34,0.55)*halo*halo*0.48;
  }
  else {
    /* --- pareti: piastre metalliche imbullonate --- */
    vec2 uv = abs(n.x) > abs(n.z) ? vec2(pos.z, pos.y) : vec2(pos.x, pos.y);
    alb = vec3(0.072,0.078,0.092);
    gloss = 0.22;

    vec2 plate = uv/vec2(1.15,0.86);
    vec2 pf = abs(fract(plate)-0.5);
    float pseam = smoothstep(0.462,0.5,max(pf.x,pf.y));
    float pbev  = smoothstep(0.40,0.5,max(pf.x,pf.y));
    vec3 wd = vnoiseD(uv*vec2(2.2,3.1));
    float grain = wd.x;
    alb = mix(alb, vec3(0.090,0.096,0.112), grain);
    alb = mix(alb, vec3(0.022,0.024,0.032), pseam*0.92);
    alb *= 0.88 + 0.16*pbev;

    alb *= 1.0 - 0.22*smoothstep(0.52,0.82,vnoise(vec2(uv.x*7.0, uv.y*0.55+9.0)));

    vec3 tng = abs(n.x) > 0.7 ? vec3(0.0,0.0,1.0) : vec3(1.0,0.0,0.0);
    nOut = normalize(n - tng*wd.y*0.28 - vec3(0.0,1.0,0.0)*wd.z*0.28);

    vec2 bolt = abs(fract(plate+0.5)-0.5)*vec2(1.15,0.86);
    float bolts = smoothstep(0.030,0.014,length(bolt));
    alb = mix(alb, vec3(0.14,0.148,0.168), bolts*0.85);
    gloss = mix(gloss, 0.58, bolts);

    float cold = smoothstep(-2.6,-3.6,pos.z);
    alb += vec3(0.022,0.040,0.062)*cold*(0.5+0.6*grain);

    emis += vec3(0.10,0.28,0.48)*smoothstep(0.060,0.018,abs(pos.y-0.115))*0.70;
    emis += vec3(0.05,0.16,0.28)*smoothstep(0.26,0.05,pos.y)*0.14;

    float conduit = smoothstep(0.012,0.0,abs(fract(pos.y*1.1+0.25)-0.5)-0.48);
    emis += vec3(0.08,0.20,0.30)*conduit*0.10;

    /* montanti che fiancheggiano la finestra */
    if(pos.z < -3.4){
      float col2 = smoothstep(0.045,0.018,abs(abs(pos.x)-3.32))
                 * smoothstep(0.35,0.6,pos.y)*smoothstep(3.15,2.7,pos.y);
      emis += vec3(0.10,0.30,0.58)*col2*0.85;
    }
    /* parete di fondo: luci di tenuta del portello */
    if(pos.z > 2.6){
      float door = smoothstep(0.95,0.72,abs(pos.x))*smoothstep(0.95,0.55,abs(pos.y-1.5));
      alb = mix(alb, vec3(0.034,0.038,0.048), door*0.6);
      emis += vec3(0.12,0.30,0.34)*smoothstep(0.03,0.0,abs(abs(pos.x)-1.15))
              *smoothstep(1.30,0.0,abs(pos.y-1.42))*0.30;
    }

    /* smussi: metallo più scuro con un filo di luce */
    if(bevelTop > 0.01){
      alb = mix(alb, vec3(0.026,0.029,0.038), bevelTop*0.85);
      emis += vec3(0.09,0.24,0.46)*smoothstep(0.055,0.02,abs(pos.y-2.98))*bevelTop*0.85;
    }
    if(bevelVert > 0.01){
      alb = mix(alb, vec3(0.029,0.032,0.040), bevelVert*0.8);
    }
  }
}

void getMaterial(float mid, vec3 pos, vec3 n, vec3 v, float fres,
                 out vec3 alb, out float gloss, out vec3 emis, out vec3 nOut){
  float t = iTime;
  alb = vec3(0.05); gloss = 0.0; emis = vec3(0.0); nOut = n;
  float hovB = uHover==2.0?1.0:0.0;
  float focT = uActive==1.0?1.0:0.0;
  float focB = uActive==2.0?1.0:0.0;

  if(mid==2.0){ shellMaterial(pos, n, alb, gloss, emis, nOut); }
  else if(mid==4.0){
    /* gunmetal satin: charcoal visibile, non nero a specchio */
    alb = vec3(0.108,0.112,0.124);
    gloss = 0.48;
    alb *= 0.93 + 0.10*fbm2(vec2(pos.x*1.4, pos.z*7.5));
  }
  else if(mid==5.0){ alb=vec3(0.048,0.050,0.060); gloss=0.32; }
  else if(mid==6.0){
    alb=vec3(0.026,0.026,0.034); gloss=0.5;
    if(focT>0.5){
      emis += vec3(0.45,0.25,1.0)*(0.35+0.35*sin(t*5.0))*pow(fres,2.0);
      emis += vec3(0.2,0.8,1.0)*0.25*(0.5+0.5*sin(t*7.0+pos.x*40.0));
    }
  }
  else if(mid==8.0){
    alb=vec3(0.035,0.033,0.060); gloss=0.5;
    vec3 bp = pos-BRD_C;
    if(n.y>0.9 && abs(bp.x)<0.22 && abs(bp.z)<0.22){
      vec2 cell = floor(bp.xz/0.055+4.0);
      float chk = mod(cell.x+cell.y,2.0);
      alb = mix(vec3(0.018,0.016,0.040), vec3(0.085,0.080,0.130), chk);
      vec2 cf = abs(fract(bp.xz/0.055+4.0)-0.5);
      float gl = smoothstep(0.5,0.45,max(cf.x,cf.y));
      emis += vec3(0.22,0.38,0.75)*(1.0-gl)*0.38;
      if(focB>0.5){
        float pulse = 0.5+0.5*sin(t*4.0+cell.x+cell.y*1.7);
        emis += mix(vec3(0.55,0.25,1.0),vec3(0.15,0.75,1.0),chk)*pulse*(1.0-gl)*0.85;
        emis += vec3(0.3,0.9,1.0)*smoothstep(0.08,0.0,abs(fract(bp.x*6.0+bp.z*6.0 - t*1.2)-0.5)-0.42)*0.35;
      }
    }
    float rim = smoothstep(0.015,0.0,abs(max(abs(bp.x),abs(bp.z))-0.235))*step(0.,n.y);
    emis += vec3(0.45,0.20,0.85)*rim*(0.7+0.5*sin(t*2.5))*(1.0+hovB*2.0);
    if(focB>0.5){
      float gate = smoothstep(0.12,0.0,abs(fract(atan(bp.z,bp.x)/6.2831853 + t*0.55)-0.5)-0.38);
      emis += vec3(0.4,0.85,1.0)*rim*gate*2.2;
      emis += vec3(0.7,0.35,1.0)*rim*(0.5+0.5*sin(t*6.0));
    }
  }
  else if(mid==12.0){
    /* bezel finestra: metallo spazzolato freddo, brina sui bordi */
    alb = vec3(0.072,0.078,0.092);
    gloss = 0.58;
    vec2 wl = pos.xy - WIN_C.xy;
    alb *= 0.90 + 0.18*fbm2(wl*6.0);
    float ribs = smoothstep(0.5,0.34,abs(fract(atan(wl.y, wl.x)*9.0/PI)-0.5));
    alb = mix(alb, vec3(0.110,0.118,0.138), ribs*0.5);
    float ice = smoothstep(0.55,1.0, fbm2(wl*4.5) + smoothstep(1.05,0.35,length(wl/WIN_B))*0.35);
    alb = mix(alb, vec3(0.26,0.33,0.42), ice*0.5);
    gloss = mix(gloss, 0.26, ice);
  }
  else if(mid==13.0){
    emis = vec3(0.52,0.15,0.64)*1.55;
    alb = vec3(0.02); gloss = 0.0;
  }
  else if(mid==14.0){
    float bedLed = smoothstep(0.28, 0.08, pos.y);
    emis = mix(vec3(0.13,0.50,0.90), vec3(0.26,0.78,1.18), bedLed)
         * (2.6 + 2.8*bedLed + 0.18*sin(t*1.2+pos.x*2.0+pos.z*1.5));
    alb = vec3(0.02); gloss = 0.0;
  }
  else if(mid==15.0){
    /* materasso: plum, più caldo e chiaro del gunmetal della scrivania */
    alb = vec3(0.22,0.155,0.175);
    gloss = 0.08;
    vec2 q = pos.xz*5.2;
    alb *= 0.88 + 0.20*smoothstep(0.35,0.5,max(abs(fract(q.x)-0.5),abs(fract(q.y)-0.5)));
    alb *= 0.90 + 0.22*fbm2(pos.xz*7.0);
  }
  else if(mid==16.0){
    /* coperta: lino taupe-polvere, contrasto netto con materasso e tavolo */
    alb = vec3(0.38,0.345,0.315);
    gloss = 0.12;
    alb *= 0.84 + 0.26*fbm2(pos.xz*5.5 + pos.y*3.0);
    float fold = 0.5 + 0.5*sin(pos.z*8.0 + pos.x*1.6);
    alb *= 0.88 + 0.18*fold;
  }
  else if(mid==17.0){
    alb=vec3(0.045,0.045,0.058); gloss=0.52;
    vec3 mp = pos-vec3(1.18,0.85,0.60);
    emis += vec3(0.45,0.20,0.80)*smoothstep(0.010,0.0,abs(mp.y-0.062))*0.75;
  }
  else if(mid==19.0){
    /* cuscino: malva polveroso */
    alb = vec3(0.32,0.245,0.268);
    gloss = 0.11;
    alb *= 0.86 + 0.24*fbm2(pos.xz*8.0 + pos.y*5.0);
  }
  else if(mid==20.0){
    /* diffusore plafoniera */
    emis = vec3(0.72,0.84,1.06)*4.6*(0.99 + 0.01*sin(t*13.0 + pos.z*4.0));
    emis *= 0.82 + 0.18*smoothstep(0.5,0.30,abs(fract(pos.z*1.55)-0.5));
    alb = vec3(0.3); gloss = 0.0;
  }
  else if(mid==21.0){
    /* condotti e tubazioni: acciaio opaco */
    alb = vec3(0.060,0.064,0.074); gloss = 0.42;
    alb *= 0.88 + 0.20*fbm2(vec2(pos.z*3.0, pos.y*3.0));
  }
  else if(mid==22.0){
    /* statuetta: bronzo alieno */
    alb = mix(vec3(0.20,0.135,0.055), vec3(0.075,0.095,0.075), fbm2(pos.xz*22.0+pos.y*9.0));
    gloss = 0.72;
    emis += vec3(0.18,0.60,0.40)*smoothstep(0.55,0.9,fbm2(pos.xy*30.0))*0.10;
  }
  else if(mid==23.0){
    /* casse di stivaggio */
    alb = vec3(0.062,0.060,0.055);
    gloss = 0.22;
    vec2 uv = vec2(pos.z, pos.y)*3.1;
    alb *= 0.88 + 0.2*smoothstep(0.42,0.5,max(abs(fract(uv.x)-0.5),abs(fract(uv.y)-0.5)));
    alb = mix(alb, vec3(0.20,0.135,0.045), smoothstep(0.62,0.85,fbm2(pos.yz*9.0))*0.5);
  }
  else if(mid==25.0){ alb = vec3(0.058,0.062,0.074); gloss = 0.45; }
  else if(mid==26.0){
    alb = vec3(0.046,0.049,0.059); gloss = 0.28;
    alb *= 0.9 + 0.18*fbm2(pos.xy*5.0+pos.z*2.0);
  }
  else if(mid==27.0){ emis = vec3(0.12,0.38,0.56)*(0.85+0.15*sin(t*0.7+pos.x*2.0)); alb=vec3(0.02); }
  else if(mid==28.0){
    alb = vec3(0.018,0.022,0.030); gloss = 0.12;
    float lines = smoothstep(0.03,0.0,abs(fract(pos.y*18.0)-0.5)-0.46);
    emis += vec3(0.10,0.26,0.34)*lines*0.20;
  }
  else if(mid==29.0){
    /* grigliato / piastre d'ispezione */
    alb = vec3(0.030,0.033,0.040); gloss = 0.30;
    alb *= 0.85 + 0.30*fbm2(pos.xz*8.0);
    emis += vec3(0.06,0.16,0.26)*0.10;
  }
  else if(mid==40.0){
    alb = vec3(0.052,0.110,0.066); gloss = 0.36;
    float vein = smoothstep(0.04,0.0,abs(fract(pos.y*12.0+pos.z*8.0)-0.5)-0.44);
    emis += mix(vec3(0.22,0.72,0.38), vec3(0.55,0.22,0.80), vein)*(0.65+0.35*sin(t*1.8+pos.y*6.0))*0.70;
  }
  else if(mid==41.0){
    alb = vec3(0.095,0.102,0.118); gloss = 0.78;
  }
  else if(mid==42.0){
    alb = vec3(0.032,0.038,0.052); gloss = 0.42;
    emis += vec3(0.14,0.48,0.70)*step(0.86,fract(pos.y*20.0+pos.z*12.0))*0.40;
  }
}

/* ============================================================
   SHADING
   ============================================================ */
const vec3 WIN_L = vec3(0.12,0.35,-1.0);

/* occlusione a contatto sotto scrivania e letto, senza march extra */
float contactAO(vec3 p){
  float dDesk = sdBox(p - DESK_C, vec3(1.58, 0.10, 0.58));
  float dBed  = sdBox(p - BED_C,  vec3(1.00, 0.22, 1.16));
  float a = mix(0.50, 1.0, smoothstep(-0.02, 0.18, dDesk));
  a *= mix(0.70, 1.0, smoothstep(-0.02, 0.20, dBed));
  return a;
}

/* luce ad area della finestra: il punto più vicino sull'apertura */
vec3 windowArea(vec3 pos, vec3 n){
  vec3 q = vec3(
    clamp(pos.x, -WIN_B.x*0.82, WIN_B.x*0.82),
    clamp(pos.y, WIN_C.y-WIN_B.y*0.78, WIN_C.y+WIN_B.y*0.78),
    WALL_F
  );
  vec3 L = q - pos;
  float d2 = dot(L,L);
  float ndl = max(dot(n, L), 0.0) * inversesqrt(max(d2, 1e-4));
  float att = 1.0 / (1.0 + d2*0.048);
  return vec3(0.74,0.84,1.08) * ndl * att * 2.55;
}

/* riflessi planari di scrivania e letto sul pavimento lucido */
vec3 planarReflect(vec3 pos, vec3 rd, float gloss, float fres){
  vec3 acc = vec3(0.0);
  vec3 rr = reflect(rd, vec3(0.0,1.0,0.0));
  if(rr.y < 0.03) return acc;
  float w = gloss * (0.22 + 0.78*fres);

  float td = (DESK_C.y + 0.035 - pos.y) / rr.y;
  if(td > 0.04 && td < 7.0){
    vec3 hp = pos + rr*td;
    vec2 d = abs((hp - DESK_C).xz);
    float inside = min(1.55-d.x, 0.55-d.y);
    if(inside > 0.0){
      float e = smoothstep(0.0, 0.035, inside);
      acc += vec3(0.055,0.058,0.068)*e;
      acc += vec3(0.42,0.14,0.58)*smoothstep(0.035,0.0,abs(d.y-0.55))*e*1.15;
    }
  }

  float tb = (BED_C.y + 0.12 - pos.y) / rr.y;
  if(tb > 0.04 && tb < 8.0){
    vec3 hp = pos + rr*tb;
    vec2 d = abs((hp - BED_C).xz);
    float inside = min(0.97-d.x, 1.12-d.y);
    if(inside > 0.0){
      float e = smoothstep(0.0, 0.05, inside);
      acc += vec3(0.085,0.072,0.078)*e;
      acc += vec3(0.20,0.62,1.05)*smoothstep(0.16,0.0,abs(d.x-0.86))*e*2.45;
      acc += vec3(0.14,0.48,0.90)*smoothstep(0.16,0.0,abs(d.y-1.02))*e*1.65;
    }
  }
  return acc * w;
}

vec3 shade(vec3 pos, vec3 rd, float mid){
  float t = iTime;
  float hovT = uHover==1.0?1.0:0.0;
  float focT = uActive==1.0?1.0:0.0;
  float hovB = uHover==2.0?1.0:0.0;
  float focB = uActive==2.0?1.0:0.0;
  float focO = uActive==3.0?1.0:0.0;

  /* emissivi puri */
  if(mid==7.0){
    vec3 tp = pos - TAB_C;
    tp.yz = rot2(0.5)*tp.yz;
    return tabletUI(vec2(tp.x/0.185, -tp.z/0.125), hovT, focT)*2.2;
  }
  if(mid>=30.0 && mid<37.0){
    int oi = int(mid-30.0);
    vec3 ca = socialColorA(oi), cb = socialColorB(oi);
    vec3 lp = pos - socialPos(oi);
    float r = 0.090;
    vec3 nA = lp / max(length(lp), 1e-4);
    float lat = clamp(lp.y / r, -1.0, 1.0);
    float lon = atan(lp.z, lp.x);
    vec3 hue = mix(ca, cb, 0.5 + 0.5*sin(lat*4.5 + lon*2.0 + t*(1.2+float(oi)*0.25)));
    float ring = smoothstep(0.14, 0.0, abs(lat - 0.2*sin(t*0.9+float(oi))));
    float hov = (uHover==8.0+float(oi)) ? 1.0 : 0.0;
    vec3 c = hue*(1.20 + 0.40*max(-nA.x,0.0)) + hue*ring*0.75 + mix(ca,cb,0.5)*0.35;
    c += vec3(1.0)*(0.06 + 0.12*hov);
    return c*(1.05 + hov*0.9);
  }

  /* LED puri: niente normali/AO/ombre */
  if(mid==13.0){
    return vec3(0.52,0.15,0.64)*(1.55+0.08*sin(t*1.6+pos.x*3.0));
  }
  if(mid==14.0){
    float bedLed = smoothstep(0.28, 0.08, pos.y);
    return mix(vec3(0.14,0.52,0.92), vec3(0.28,0.82,1.25), bedLed)
         * (2.8 + 3.2*bedLed + 0.18*sin(t*1.2+pos.x*2.0+pos.z*1.5));
  }
  if(mid==20.0){
    vec3 e = vec3(0.78,0.90,1.12)*5.2*(0.99 + 0.01*sin(t*13.0 + pos.z*4.0));
    return e*(0.82 + 0.18*smoothstep(0.5,0.30,abs(fract(pos.z*1.55)-0.5)));
  }
  if(mid==27.0){
    return vec3(0.14,0.42,0.62)*(0.90+0.15*sin(t*0.7+pos.x*2.0));
  }

  vec3 n = calcNormal(pos);
  vec3 v = -rd;
  float fres = pow(1.0-max(dot(n,v),0.0),3.0);

  if(mid==10.0||mid==11.0){
    vec3 hue = mid==10.0 ? vec3(0.65,0.25,1.0) : vec3(0.15,0.65,1.0);
    vec3 c = hue*(0.6+0.8*fres) + hue*(0.5+0.5*sin(pos.y*40.0+t*2.0))*0.30 + hue*hovB*0.8;
    if(focB>0.5){
      float aura = 0.55+0.45*sin(t*5.0+pos.y*30.0);
      float ring = smoothstep(0.08,0.0,abs(fract(pos.y*18.0-t*2.5)-0.5)-0.38);
      c += hue*aura*0.55 + hue*ring*0.7 + hue*(0.5+0.5*sin(t*3.2+pos.x*20.0+pos.z*17.0))*0.35;
      c *= 1.15+0.2*sin(t*4.0);
    }
    return c;
  }
  if(mid>=50.0 && mid<58.0){
    int oi = int(mid-50.0);
    vec3 ca = uOrbA[oi], cb = uOrbB[oi];
    vec3 lp = pos-orbPos(oi);
    float r = uOrbR[oi];
    float lat = lp.y/r;
    float lon = atan(lp.z,lp.x);
    vec3 hue = mix(ca, cb, 0.5+0.5*sin(lat*6.0 + lon*2.0 + t*(1.2+float(oi)*0.35)));
    float ring = smoothstep(0.10,0.0,abs(lat-sin(t*0.9+float(oi)*2.1)*0.5));
    float hov = (uHover==4.0+float(oi))?1.0:0.0;
    float act = (uActive==4.0+float(oi))?1.0:0.0;
    vec3 c = hue*(0.50+1.0*fres) + hue*ring*0.65 + mix(ca,cb,0.5)*0.22;
    c *= 0.85+0.15*sin(t*5.0+lat*20.0);
    if(act>0.5){
      float shell = pow(fres, 1.2)*(0.6+0.4*sin(t*6.0+lon*4.0));
      float band = smoothstep(0.07,0.0,abs(fract(lon/6.2831853*3.0 - t*0.8)-0.5)-0.4);
      float spark = step(0.92, hash11(floor(lat*12.0)+floor(lon*8.0)+floor(t*10.0)));
      c += mix(ca,cb,0.5)*shell*1.4 + hue*band*0.9 + vec3(1.0)*spark*0.55;
      c *= 1.2+0.35*(0.5+0.5*sin(t*4.5));
    }
    return c*(1.05+hov*1.2+act*0.5);
  }
  if(mid==24.0){
    float hovO = uHover==3.0?1.0:0.0;
    vec3 q = octToLocal(pos-OCT_C);
    vec3 alb = mix(vec3(0.52,0.18,0.86), vec3(0.30,0.10,0.68), clamp(q.y*6.0+0.2,0.,1.));
    vec3 hq = q - vec3(0.,0.085+0.008*sin(t*2.0),0.);
    float eyeL = length(hq-vec3(0.026,0.012,0.052));
    float eyeR = length(hq-vec3(-0.026,0.012,0.052));
    vec3 emis = vec3(0.0);
    if(eyeL < 0.007 || eyeR < 0.007) alb = vec3(0.02);
    else if(eyeL < 0.016 || eyeR < 0.016) alb = vec3(0.95);
    if(focO>0.5){
      float circuit = smoothstep(0.04,0.0,abs(fract(atan(q.z,q.x)*4.0 + t*1.5)-0.5)-0.42);
      emis += vec3(0.55,0.3,1.0)*circuit*(0.5+0.5*sin(t*7.0+q.y*40.0))*0.85;
      emis += vec3(0.4,0.85,1.0)*pow(fres,1.5)*(0.7+0.3*sin(t*5.0))*0.9;
      if(eyeL < 0.016 || eyeR < 0.016) emis += vec3(0.3,0.9,1.0)*(0.4+0.6*sin(t*8.0));
    }
    vec3 L = normalize(vec3(0.3,0.8,-0.4));
    float dif = max(dot(n, L),0.0);
    vec3 c = alb*(0.22+0.55*dif) + emis;
    c += vec3(0.55,0.32,0.80)*fres*0.25;
    c += alb*hovO*0.9;
    c += stripLighting(pos, n, 1.0)*alb*1.4;
    if(focO>0.5) c *= 1.1+0.15*sin(t*4.5);
    return c;
  }

  /* ----- materiali generici ----- */
  vec3 alb, emis, nOut; float gloss;
  getMaterial(mid, pos, n, v, fres, alb, gloss, emis, nOut);
  n = nOut;
  fres = pow(1.0-max(dot(n,v),0.0),3.0);

  float ao = calcAO(pos,n) * contactAO(pos);
  vec3 col = vec3(0.0);

  /* luce dalla finestra: direzionale (ombre) + area (diffusione morbida) */
  vec3 Lw = normalize(WIN_L);
  float ndl = max(dot(n,Lw),0.0);
  float sh = (ndl < 0.04 || n.y < -0.25) ? 0.0 : softShadow(pos+n*0.02, Lw);
  col += alb * ndl * sh * vec3(0.70,0.82,1.04) * 1.35;
  if(n.z < 0.25) col += alb * windowArea(pos, n) * mix(0.35, 1.0, sh);

  /* ambiente navy: basso, ma i pannelli restano leggibili */
  col += alb * (0.28+0.32*n.y) * vec3(0.055,0.068,0.100) * ao;
  col += alb * max(-n.z,0.0) * vec3(0.048,0.070,0.120) * ao;

  /* strisce LED */
  col += stripLighting(pos, n, ao) * alb * 1.35;
  if(mid==15.0 || mid==16.0 || mid==19.0){
    /* fill caldo: le lenzuola restano taupe/plum, non navy come il tavolo */
    col += alb * vec3(0.30,0.26,0.24) * (0.85 + 0.40*n.y);
    col += alb * vec3(0.10,0.28,0.55) * max(-n.x,0.0) * 0.40;
    col += vec3(0.032,0.024,0.022);
  }

  if(gloss > 0.05){
    vec3 rr = reflect(rd,n);
    if(mid==4.0){
      /* satin: specchiature strette delle plafoniere, niente alone viola */
      col += stripGlowN(pos + n*0.02, rr, 11.0, 58.0, 2) * (0.18 + 0.55*fres);
      float sx = abs(abs(pos.x) - 1.08);
      float streak = exp(-sx*sx*20.0) * smoothstep(0.52, 0.18, abs(pos.z - DESK_C.z));
      col += vec3(0.72,0.82,1.00) * streak * (0.14 + 0.22*max(dot(n,v),0.0));
      col += alb * vec3(0.20,0.30,0.46) * 0.38;
      if(rr.z < -0.05){
        float tw = (GLASS_Z-pos.z)/rr.z;
        if(tw > 0.0 && sdOctRect((pos+rr*tw).xy-WIN_C.xy, WIN_B, WIN_CH) < 0.0){
          col += skyLite(rr)*(0.10+0.32*fres)*gloss;
        }
      }
      vec3 H = normalize(Lw + v);
      float spec = pow(max(dot(n,H),0.0), 36.0) * gloss * mix(0.20, 0.85, sh);
      col += spec * vec3(0.78,0.86,1.02) * 0.35;
    } else {
      float gk = n.y > 0.65 ? 11.0 : 26.0;
      col += stripGlow(pos + n*0.02, rr, 11.0, gk) * (0.10 + 0.90*fres) * gloss * 1.25;
      if(rr.z < -0.05){
        float tw = (GLASS_Z-pos.z)/rr.z;
        if(tw > 0.0 && sdOctRect((pos+rr*tw).xy-WIN_C.xy, WIN_B, WIN_CH) < 0.0){
          col += skyLite(rr)*(0.18+0.82*fres)*gloss*1.85;
        }
      }
      if(n.y > 0.65 && pos.y < 0.12){
        col += planarReflect(pos, rd, gloss, fres);
      }
      vec3 H = normalize(Lw + v);
      float spec = pow(max(dot(n,H),0.0), mix(20.0, 90.0, gloss)) * gloss * mix(0.25, 1.0, sh);
      col += spec * vec3(0.72,0.84,1.06) * 0.62;
    }
  }

  col += emis;
  return col;
}

/* ============================================================
   VOLUMETRICA: foschia, fascio dalla finestra, glow dei LED
   ============================================================ */
vec3 volumetrics(vec3 ro, vec3 rd, float tmax){
  vec3 acc = vec3(0.0);
  float far = min(tmax, 12.0);
  const float STEPS = 6.0;
  float dt = far/STEPS;
  float jit = hash21(gl_FragCoord.xy + fract(iTime)*13.0)*dt;

  vec3 Ld = normalize(vec3(-0.10,-0.26,1.0));
  float phase = 0.20 + 0.80*pow(max(dot(rd,Ld),0.0), 5.0);

  for(int i=0;i<6;i++){
    float ti = dt*float(i) + jit;
    if(ti > far) break;
    vec3 p = ro + rd*ti;
    float dens = exp(-max(p.y,0.0)*0.55) * (0.5 + 0.6*vnoise(p.xz*0.55 + vec2(iTime*0.04,-iTime*0.03)));

    /* il punto è nel cono di luce della finestra? */
    float s = (WALL_F - p.z)/Ld.z;
    float inside = smoothstep(0.05,-0.45, sdOctRect((p + Ld*s).xy - WIN_C.xy, WIN_B, WIN_CH));
    float reach = exp(-max(p.z - WALL_F, 0.0)*0.70);
    acc += vec3(0.26,0.38,0.72) * inside * reach * phase * dens * dt * 0.52;
    acc += vec3(0.013,0.019,0.038) * dens * dt * 0.16;
  }

  acc += stripGlow(ro, rd, far, 11.0) * 0.14;
  return acc;
}

/* ============================================================
   MAIN
   ============================================================ */
void main(){
  vec2 frag = gl_FragCoord.xy;
  vec2 uv = (2.0*frag - iResolution)/iResolution.y;
  uv.x -= uViewBias * 0.50 * (iResolution.x / iResolution.y);

  vec3 ro = uCamRo;
  vec3 fw = normalize(uCamTarget - uCamRo);
  vec3 rt = normalize(cross(fw, vec3(0.,1.,0.)));
  vec3 up = cross(rt,fw);
  vec3 rd = normalize(fw*uCamFocal + uv.x*rt + uv.y*up);

  vec2 hit = march(ro,rd);
  vec3 col;
  float depth = hit.y < 0.0 ? 18.0 : hit.x;

  if(hit.y<0.0){
    col = renderCity(ro,rd);

    /* --- vetro: brina, riflessi della stanza --- */
    float tw = (GLASS_Z-ro.z)/rd.z;
    if(tw > 0.0){
      vec3 wp = ro+rd*tw;
      vec2 wl = wp.xy-WIN_C.xy;
      float inner = -sdOctRect(wl, WIN_B, WIN_CH);   /* >0 dentro l'apertura */

      /* brina: cresce dal bordo verso il centro, più densa in basso */
      float grow = fbm2(wl*3.1 + 17.0);
      float bias = 0.30 + 0.45*smoothstep(0.9,-0.6, wl.y);
      float frost = clamp(smoothstep(0.62, 0.02, inner - (grow-0.5)*0.85 - (bias-0.45)), 0.0, 1.0);
      float crystal = fbm2(wl*vec2(13.0,9.5) + 5.0);
      vec3 iceCol = vec3(0.24,0.33,0.46)*(0.45+0.75*crystal);
      col = mix(col, iceCol*0.80 + col*0.30, frost*0.88);
      col += vec3(0.34,0.46,0.64)*smoothstep(0.72,0.95,crystal)*frost*0.40;

      /* riflesso della stanza sul vetro */
      col += stripGlow(wp, reflect(rd, vec3(0.,0.,1.)), 9.0, 7.0)*0.24;

      vec2 wuv = wl/WIN_B;
      col += vec3(0.28,0.38,0.62)*smoothstep(0.35,0.0,abs(wuv.x-wuv.y*0.6+0.3))*0.022;
      col *= 1.0-0.09*length(wuv*wuv);
    }
  } else {
    vec3 pos = ro+rd*hit.x;
    col = shade(pos,rd,hit.y);
    col = mix(col, vec3(0.014,0.019,0.033), 1.0-exp(-hit.x*0.055));
  }

  col += volumetrics(ro, rd, depth);

  fragColor = vec4(col,1.0);
}
