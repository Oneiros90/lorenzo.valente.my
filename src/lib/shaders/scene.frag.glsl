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
uniform vec3  uOrbA[4];
uniform vec3  uOrbB[4];
uniform float uOrbR[4];

/* ---------- utility ---------- */
#define PI 3.14159265
float hash11(float n){ return fract(sin(n*127.1)*43758.5453123); }
float hash21(vec2 p){ p = fract(p*vec2(123.34,456.21)); p += dot(p,p+45.32); return fract(p.x*p.y); }
mat2 rot2(float a){ float c=cos(a),s=sin(a); return mat2(c,-s,s,c); }

float sdBox(vec3 p, vec3 b){ vec3 q=abs(p)-b; return length(max(q,0.))+min(max(q.x,max(q.y,q.z)),0.); }
float sdRoundBox(vec3 p, vec3 b, float r){ vec3 q=abs(p)-b; return length(max(q,0.))+min(max(q.x,max(q.y,q.z)),0.)-r; }
float sdSphere(vec3 p, float r){ return length(p)-r; }
float sdCylinder(vec3 p, float h, float r){ vec2 d=abs(vec2(length(p.xz),p.y))-vec2(r,h); return min(max(d.x,d.y),0.)+length(max(d,0.)); }
float sdRoundCone(vec3 p, float r1, float r2, float h){
  vec2 q=vec2(length(p.xz),p.y);
  float b=(r1-r2)/h, a=sqrt(1.-b*b), k=dot(q,vec2(-b,a));
  if(k<0.) return length(q)-r1;
  if(k>a*h) return length(q-vec2(0.,h))-r2;
  return dot(q,vec2(a,b))-r1;
}
float smin(float a, float b, float k){
  float h=clamp(0.5+0.5*(b-a)/k,0.,1.);
  return mix(b,a,h)-k*h*(1.-h);
}
vec2 opU(vec2 a, vec2 b){ return a.x<b.x?a:b; }

/* ---------- layout ---------- */
const vec3 WIN_C = vec3(0.,1.8,-3.8);
const vec2 WIN_B = vec2(2.95,1.12);
const vec3 TAB_C = vec3(-0.70,0.83,0.80);
const vec3 BRD_C = vec3(0.58,0.805,0.82);
const vec3 OCT_C = vec3(1.12,0.80,1.10);
const float OCT_YAW = atan(0.0 - OCT_C.x, 2.10 - OCT_C.z);
vec3 octToLocal(vec3 q){
  float c = cos(OCT_YAW), s = sin(OCT_YAW);
  return vec3(c*q.x - s*q.z, q.y, s*q.x + c*q.z);
}
vec3 orbPos(int i){
  float fi = float(i);
  float z = 1.18 - fi*0.16;
  float xOff = (mod(fi, 2.0) < 0.5) ? -0.05 : 0.25;
  float r = uOrbR[i];
  return vec3(-0.22 + xOff, 0.795 + r + 0.015*sin(iTime*1.3+fi*1.9), z);
}
vec3 socialPos(int i){
  /* DAVANTI alle mensole (verso la camera/stanza), non dietro il bordo
     Mensola: x∈[~3.43,3.67] → orb a x=3.18, r=0.09 → interamente davanti */
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
float sdCapsule(vec3 p, vec3 a, vec3 b, float r){
  vec3 pa=p-a, ba=b-a;
  float h=clamp(dot(pa,ba)/dot(ba,ba),0.,1.);
  return length(pa-ba*h)-r;
}

/* occupazione scacchiera */
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

/* ---------- mappa SDF ---------- */
vec2 map(vec3 p){
  /* stanza: pavimento, soffitto, pareti */
  float room = sdBox(p-vec3(0.,-0.1,-0.5), vec3(3.9,0.1,3.5));           // pavimento
  room = min(room, sdBox(p-vec3(0.,3.3,-0.5), vec3(3.9,0.1,3.5)));       // soffitto
  room = min(room, sdBox(p-vec3(-3.7,1.6,-0.5), vec3(0.1,1.8,3.5)));     // parete sx
  room = min(room, sdBox(p-vec3( 3.7,1.6,-0.5), vec3(0.1,1.8,3.5)));     // parete dx
  room = min(room, sdBox(p-vec3(0.,1.6, 3.0), vec3(3.9,1.8,0.12)));      // parete dietro
  float wallF = max( sdBox(p-vec3(0.,1.6,-3.8), vec3(3.9,1.8,0.12)),
                    -sdBox(p-vec3(WIN_C.xy,-3.8), vec3(WIN_B,0.5)) );    // parete finestra
  room = min(room, wallF);
  vec2 res = vec2(room, 2.0);

  /* cornice finestra — bezel sottile + corner brackets */
  float fr = sdBox(p-vec3(0.,1.8,-3.66), vec3(3.02,1.18,0.04));
  fr = max(fr, -sdBox(p-vec3(0.,1.8,-3.66), vec3(2.93,1.10,0.3)));
  res = opU(res, vec2(fr,12.0));
  if(abs(p.z+3.66)<0.18){
    vec2 corner = abs(p.xy - WIN_C.xy) - (WIN_B - vec2(0.08));
    if(abs(corner.x)<0.22 && abs(corner.y)<0.22){
      float br = sdBox(p-vec3(sign(p.x-WIN_C.x)*(WIN_B.x-0.04), sign(p.y-WIN_C.y)*(WIN_B.y-0.04), -3.66),
                       vec3(0.10,0.10,0.035));
      float cut = sdBox(p-vec3(sign(p.x-WIN_C.x)*(WIN_B.x-0.14), sign(p.y-WIN_C.y)*(WIN_B.y-0.14), -3.66),
                        vec3(0.08,0.08,0.08));
      res = opU(res, vec2(max(br, -cut), 14.0));
    }
  }

  /* scrivania */
  vec3 dp = p - vec3(0.,0.75,0.85);
  res = opU(res, vec2(sdRoundBox(dp, vec3(1.55,0.035,0.55),0.02), 4.0));
  res = opU(res, vec2(sdBox(vec3(abs(dp.x)-1.35,dp.y+0.42,dp.z), vec3(0.05,0.38,0.45)), 5.0));
  res = opU(res, vec2(sdBox(dp-vec3(0.,-0.06,0.54), vec3(1.5,0.012,0.012)), 13.0)); // strip viola

  /* tablet inclinato */
  vec3 tp = p - TAB_C;
  tp.yz = rot2(0.5)*tp.yz;
  res = opU(res, vec2(sdRoundBox(tp, vec3(0.21,0.012,0.15),0.008), 6.0));
  res = opU(res, vec2(sdBox(tp-vec3(0.,0.024,0.), vec3(0.185,0.004,0.125)), 7.0));

  /* scacchiera (compatta) */
  vec3 bp = p - BRD_C;
  res = opU(res, vec2(sdRoundBox(bp, vec3(0.24,0.018,0.24),0.008), 8.0));
  vec3 pp = bp - vec3(0.,0.018,0.);
  if(abs(pp.x)<0.23 && abs(pp.z)<0.23 && pp.y>-0.02 && pp.y<0.18){
    vec2 cell = clamp(floor(pp.xz/0.055+4.0), 0.0, 7.0);
    if(occupancy(cell)>0.5){
      vec2 cc = (cell-3.5)*0.055;
      vec3 lp = vec3(pp.x-cc.x, pp.y, pp.z-cc.y);
      float t = pieceProfile(cell);
      float h = 0.030+0.034*t;
      float d = sdRoundCone(lp, 0.016, 0.008, h);
      d = min(d, sdSphere(lp-vec3(0.,h+0.004,0.), 0.010+t*0.006));
      float side = cell.y<4.0 ? 10.0 : 11.0;
      res = opU(res, vec2(d, side));
    }
  }

  /* sfere olografiche aziende (fluttuanti su piedistalli; LOD: pedestallo solo da vicino) */
  for(int i=0;i<4;i++){
    vec3 op = orbPos(i);
    float r = uOrbR[i];
    res = opU(res, vec2(sdSphere(p-op, r), 20.0+float(i)));
    if(length(p-vec3(op.x,0.80,op.z)) < 0.28){
      res = opU(res, vec2(sdCylinder(p-vec3(op.x,0.795,op.z), 0.010,0.035), 5.0));
      res = opU(res, vec2(sdCylinder(p-vec3(op.x,0.806,op.z), 0.003,0.030), 14.0));
    }
  }

  /* polpo octocat (rivolto verso la camera) */
  {
    vec3 q = octToLocal(p - OCT_C);
    if(length(q)<0.38){
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

      float earL = sdCapsule(hq, vec3(-0.030,0.042,0.010), vec3(-0.050,0.098,0.002), 0.011);
      float earR = sdCapsule(hq, vec3(0.030,0.042,0.010), vec3(0.050,0.098,0.002), 0.011);
      float ears = min(earL, earR);

      float oct = smin(body, legs, 0.02);
      oct = smin(oct, ears, 0.012);
      res = opU(res, vec2(oct, 24.0));
    }
  }

  /* letto (gate AABB) */
  {
    vec3 ep = p - vec3(2.55,0.34,-1.6);
    if(abs(ep.x)<1.25 && abs(ep.y)<0.55 && abs(ep.z)<1.45){
      res = opU(res, vec2(sdRoundBox(ep, vec3(1.0,0.13,1.15),0.06), 15.0));
      res = opU(res, vec2(sdBox(ep-vec3(0.,-0.22,0.), vec3(0.9,0.1,1.05)), 5.0));
      res = opU(res, vec2(sdBox(ep-vec3(0.,-0.13,0.), vec3(0.94,0.008,1.09)), 14.0)); // glow blu
      res = opU(res, vec2(sdRoundBox(ep-vec3(0.,0.14,-0.85), vec3(0.72,0.055,0.22),0.045), 15.0)); // cuscino
    }
  }

  /* neon soffitto (tenue) */
  res = opU(res, vec2(sdBox(vec3(abs(p.x)-1.9,p.y-3.17,p.z+0.5), vec3(0.018,0.012,2.7)), 14.0));

  /* ---- mensole habitat (early-out per muro) ---- */
  /* MURO SINISTRO: mensole + piante aliene, armi, tech (non cliccabili) */
  if(p.x < -2.6){
    /* tre mensole */
    for(int s=0;s<3;s++){
      float sy = 0.88 + float(s)*0.75;
      res = opU(res, vec2(sdRoundBox(p-vec3(-3.48,sy,-0.45), vec3(0.20,0.022,1.15),0.012), 25.0));
      /* supporti a muro */
      res = opU(res, vec2(sdBox(p-vec3(-3.58,sy-0.04,-1.35), vec3(0.04,0.05,0.04)), 25.0));
      res = opU(res, vec2(sdBox(p-vec3(-3.58,sy-0.04, 0.45), vec3(0.04,0.05,0.04)), 25.0));
    }

    /* --- mensola alta: attrezzatura tech --- */
    {
      float y = 0.88+2.0*0.75;
      /* monitor / pannello */
      res = opU(res, vec2(sdRoundBox(p-vec3(-3.42,y+0.12,-1.15), vec3(0.04,0.11,0.16),0.01), 42.0));
      /* antenna cylinder */
      res = opU(res, vec2(sdCylinder(p-vec3(-3.40,y+0.18,-0.55), 0.12, 0.018), 25.0));
      res = opU(res, vec2(sdSphere(p-vec3(-3.40,y+0.32,-0.55), 0.035), 42.0));
      /* scanner cubico */
      res = opU(res, vec2(sdRoundBox(p-vec3(-3.40,y+0.07,0.05), vec3(0.08,0.06,0.10),0.015), 42.0));
      /* batteria / cella energia */
      res = opU(res, vec2(sdRoundBox(p-vec3(-3.38,y+0.08,0.55), vec3(0.06,0.07,0.06),0.01), 26.0));
      res = opU(res, vec2(sdBox(p-vec3(-3.32,y+0.08,0.55), vec3(0.008,0.04,0.04)), 27.0));
      /* piccolo drone ripiegato */
      res = opU(res, vec2(sdRoundBox(p-vec3(-3.40,y+0.05,-0.05), vec3(0.10,0.035,0.07),0.012), 25.0));
    }

    /* --- mensola media: piante aliene --- */
    {
      float y = 0.88+1.0*0.75;
      /* vaso 1 + pianta bulbosa */
      vec3 pot1 = vec3(-3.40, y+0.05, -1.20);
      res = opU(res, vec2(sdRoundBox(p-pot1, vec3(0.07,0.05,0.07),0.02), 26.0));
      {
        vec3 q = p - (pot1+vec3(0.,0.12,0.));
        float bulb = sdSphere(q, 0.09);
        float tend = sdCapsule(q, vec3(0.02,0.05,0.), vec3(0.12,0.18,0.05), 0.018);
        tend = min(tend, sdCapsule(q, vec3(-0.02,0.04,0.), vec3(-0.10,0.20,-0.04), 0.015));
        float leaf = sdSphere(q-vec3(0.08,0.16,0.04), 0.045);
        leaf = min(leaf, sdSphere(q-vec3(-0.07,0.18,-0.03), 0.04));
        float plant = smin(bulb, smin(tend, leaf, 0.03), 0.04);
        res = opU(res, vec2(plant, 40.0));
      }
      /* vaso 2 + spirale */
      vec3 pot2 = vec3(-3.40, y+0.05, -0.35);
      res = opU(res, vec2(sdCylinder(p-pot2, 0.055, 0.065), 26.0));
      {
        vec3 q = p - (pot2+vec3(0.,0.08,0.));
        float stem = sdCapsule(q, vec3(0.), vec3(0.,0.28,0.), 0.02);
        float coil = 1000.0;
        for(int k=0;k<4;k++){
          float a = float(k)*1.2 + iTime*0.3;
          vec3 tip = vec3(0.08*cos(a), 0.08+float(k)*0.06, 0.08*sin(a));
          coil = min(coil, sdSphere(q-tip, 0.035));
        }
        res = opU(res, vec2(smin(stem, coil, 0.03), 40.0));
      }
      /* vaso 3 + cristallo organico */
      vec3 pot3 = vec3(-3.40, y+0.05, 0.45);
      res = opU(res, vec2(sdRoundBox(p-pot3, vec3(0.06,0.045,0.06),0.015), 26.0));
      {
        vec3 q = p - (pot3+vec3(0.,0.10,0.));
        float c1 = sdCapsule(q, vec3(0.), vec3(0.02,0.22,0.01), 0.025);
        float c2 = sdCapsule(q, vec3(0.), vec3(-0.06,0.16,0.04), 0.018);
        float c3 = sdCapsule(q, vec3(0.), vec3(0.05,0.14,-0.05), 0.016);
        res = opU(res, vec2(min(c1,min(c2,c3)), 40.0));
      }
    }

    /* --- mensola bassa: armi --- */
    {
      float y = 0.88;
      /* fucile lungo */
      {
        vec3 wp = p - vec3(-3.38, y+0.06, -0.9);
        float barrel = sdCapsule(wp, vec3(0.,0.,-0.55), vec3(0.,0.,0.55), 0.022);
        float stock = sdRoundBox(wp-vec3(0.02,-0.02,-0.42), vec3(0.04,0.05,0.12),0.01);
        float sight = sdBox(wp-vec3(0.,0.04,0.15), vec3(0.015,0.03,0.04));
        res = opU(res, vec2(min(barrel,min(stock,sight)), 41.0));
      }
      /* pistola */
      {
        vec3 wp = p - vec3(-3.38, y+0.05, 0.15);
        float body = sdRoundBox(wp, vec3(0.035,0.04,0.12),0.012);
        float grip = sdRoundBox(wp-vec3(0.,-0.06,-0.02), vec3(0.03,0.055,0.04),0.01);
        res = opU(res, vec2(min(body,grip), 41.0));
      }
      /* lama energetica / katana short */
      {
        vec3 wp = p - vec3(-3.38, y+0.07, 0.75);
        float blade = sdCapsule(wp, vec3(0.,0.,-0.35), vec3(0.,0.,0.35), 0.012);
        float hilt = sdCylinder(wp-vec3(0.,0.,-0.38), 0.04, 0.028);
        res = opU(res, vec2(min(blade,hilt), 41.0));
        res = opU(res, vec2(sdCapsule(wp, vec3(0.,0.,-0.32), vec3(0.,0.,0.32), 0.006), 27.0));
      }
    }
  }

  /* MURO DESTRO: mensole (gate largo) + sfere SEMPRE in map (SDF continuo!).
     Gate stretto tipo p.x>3.05 faceva overshoot del march → colpiva lo scaffale
     al posto della sfera (fasce nere). Le sfere devono essere visibili da lontano
     nel campo di distanza. */
  if(p.x > 2.6){
    for(int s=0;s<3;s++){
      float sy = 0.88 + float(s)*0.75;
      res = opU(res, vec2(sdRoundBox(p-vec3(3.55,sy,-0.70), vec3(0.12,0.018,1.05),0.01), 25.0));
      res = opU(res, vec2(sdBox(p-vec3(3.62,sy-0.03,-1.50), vec3(0.03,0.04,0.03)), 25.0));
      res = opU(res, vec2(sdBox(p-vec3(3.62,sy-0.03, 0.10), vec3(0.03,0.04,0.03)), 25.0));
    }
  }
  /* social orbs: mai dietro un early-out — sempre nel SDF */
  {
    for(int i=0;i<7;i++){
      vec3 op = socialPos(i);
      res = opU(res, vec2(sdSphere(p-op, 0.090), 30.0+float(i)));
    }
  }

  if(p.z > 2.55){
    for(int k=0;k<2;k++){
      float fk=float(k)*2.0-1.0;
      res = opU(res, vec2(sdBox(p-vec3(fk*1.6,1.7,2.88), vec3(0.06,1.35,0.05)), 26.0));
    }
    res = opU(res, vec2(sdRoundBox(p-vec3(-1.2,2.2,2.86), vec3(0.55,0.22,0.04),0.02), 28.0));
    res = opU(res, vec2(sdBox(p-vec3(-1.2,2.2,2.82), vec3(0.48,0.16,0.01)), 27.0));
    res = opU(res, vec2(sdRoundBox(p-vec3(1.4,1.35,2.86), vec3(0.35,0.45,0.05),0.02), 26.0));
  }
  if(p.y > 2.9){
    res = opU(res, vec2(sdRoundBox(p-vec3(0.0,3.12,-1.5), vec3(0.9,0.04,0.35),0.02), 26.0));
    float grill = sdBox(p-vec3(0.0,3.08,-1.5), vec3(0.75,0.01,0.28));
    res = opU(res, vec2(grill, 28.0));
    res = opU(res, vec2(sdCylinder(p-vec3(-2.6,3.05,0.8), 0.02, 0.8), 25.0));
    res = opU(res, vec2(sdCylinder(p-vec3( 2.6,3.05,0.8), 0.02, 0.8), 25.0));
  }

  /* tazza + gadget olografico */
  res = opU(res, vec2(sdCylinder(p-vec3(1.18,0.85,0.60), 0.065,0.045), 17.0));
  res = opU(res, vec2(sdBox(p-vec3(-1.28,0.84,0.55), vec3(0.045,0.045,0.045)), 18.0));

  return res;
}

/* ---------- march / normali / AO / ombre ---------- */
vec2 march(vec3 ro, vec3 rd){
  float t=0.0, m=-1.0;
  for(int i=0;i<96;i++){
    vec2 h = map(ro+rd*t);
    if(h.x < 0.0006*t+0.0004){ m=h.y; break; }
    t += h.x;
    if(t>22.0){ m=-1.0; break; }
  }
  if(t>22.0) m=-1.0;
  return vec2(t,m);
}
vec3 calcNormal(vec3 p){
  float e=0.002;
  return normalize(vec3(
    map(p+vec3(e,0.,0.)).x - map(p-vec3(e,0.,0.)).x,
    map(p+vec3(0.,e,0.)).x - map(p-vec3(0.,e,0.)).x,
    map(p+vec3(0.,0.,e)).x - map(p-vec3(0.,0.,e)).x
  ));
}
float calcAO(vec3 p, vec3 n){
  float occ=0., sca=1.;
  for(int i=1;i<=3;i++){
    float h=0.03+0.12*float(i)/3.0;
    occ += (h-map(p+n*h).x)*sca;
    sca *= 0.7;
  }
  return clamp(1.0-2.4*occ,0.,1.);
}
float softShadow(vec3 ro, vec3 rd){
  float res=1.0, t=0.03;
  for(int i=0;i<12;i++){
    float h=map(ro+rd*t).x;
    res=min(res,9.0*h/t);
    t+=clamp(h,0.04,0.4);
    if(res<0.02||t>7.0) break;
  }
  return clamp(res,0.,1.);
}

/* ============================================================
   CITTÀ PROCEDURALE (vista dalla finestra)
   ============================================================ */
vec3 renderCity(vec3 ro, vec3 rd){
  float t = iTime;
  vec3 fogCol = vec3(0.08,0.10,0.16);

  /* A. cielo notte */
  vec3 col = mix(vec3(0.02,0.03,0.06), vec3(0.04,0.06,0.12), clamp(rd.y*0.5+0.5,0.,1.));
  {
    vec3 n1 = normalize(vec3(0.35,0.55,-0.7));
    vec3 n2 = normalize(vec3(-0.55,0.25,-0.6));
    col += vec3(0.25,0.08,0.35)*exp(-dot(rd-n1,rd-n1)*18.0)*0.12;
    col += vec3(0.05,0.18,0.35)*exp(-dot(rd-n2,rd-n2)*22.0)*0.10;
  }

  /* B. Saturno — alto-sinistra, intero nel frame */
  float satDisk = 0.0;
  vec3 satDir = normalize(vec3(-0.28,0.16,-1.0));
  {
    float ca = dot(rd,satDir);
    float ang = acos(clamp(ca,-1.,1.));
    float diskR = 0.118;

    /* anelli: metà anteriore SOPRA il pianeta, metà posteriore dietro */
    vec3 rx = normalize(cross(satDir, vec3(0.,1.,0.)));
    vec3 ry = normalize(cross(satDir, rx));
    vec3 v = rd - satDir*ca;
    vec2 e = vec2(dot(v,rx)/0.26, dot(v,ry)/0.058);
    float rr = length(e);
    float ringBand = smoothstep(0.42,0.50,rr)*smoothstep(1.18,1.05,rr);
    float cassini = 1.0 - smoothstep(0.74,0.76,rr)*smoothstep(0.82,0.80,rr);
    float rb = 0.55+0.45*sin(rr*62.0);
    float ringA = ringBand*cassini*rb;
    /* e.y < 0 = metà più vicina alla camera (davanti al disco) */
    float isFront = step(e.y, 0.0);
    vec3 ringCol = vec3(0.58,0.52,0.46)*(0.55+0.45*rb) + vec3(0.35,0.32,0.36)*0.25;

    /* 1) anelli dietro (solo fuori dal disco) */
    if(isFront < 0.5 && ang > diskR+0.002){
      col += ringCol * ringA * 0.85;
    }

    /* 2) disco pianeta */
    satDisk = smoothstep(diskR+0.006, diskR-0.003, ang);
    col += vec3(0.55,0.48,0.40)*exp(-ang*ang*140.0)*0.28;
    if(satDisk>0.001){
      float band =
        0.45*sin((rd.y-satDir.y)*120.0) +
        0.30*sin((rd.y-satDir.y)*200.0+0.7) +
        0.20*sin((rd.x-satDir.x)*90.0) +
        0.15*sin((rd.y-satDir.y)*300.0);
      band = 0.5+0.5*band;
      vec3 sc = mix(vec3(0.42,0.38,0.34), vec3(0.78,0.72,0.62), band);
      sc = mix(sc, vec3(0.55,0.50,0.48), smoothstep(0.35,0.75,abs(rd.y-satDir.y)*12.0));
      float shade = smoothstep(-0.12,0.12,(rd.x-satDir.x)+0.03);
      float limb = smoothstep(0.0,0.025,diskR-ang);
      col = mix(col, sc*(0.40+0.60*shade)*limb, satDisk);
    }

    /* 3) anelli davanti (passano SOPRA il pianeta) */
    if(isFront > 0.5){
      col += ringCol * ringA * 0.95;
    }
  }

  /* stelle (dopo Saturno: non sopra il disco) */
  if(rd.y>0.05 && satDisk<0.5){
    vec2 sph = vec2(atan(rd.x,-rd.z), asin(clamp(rd.y,-1.,1.)));
    vec2 sg = sph*220.0;
    vec2 sid = floor(sg);
    float sh = hash21(sid);
    if(sh>0.972){
      vec2 sf = fract(sg)-0.5;
      float st = smoothstep(0.22,0.0,length(sf));
      float tw = 0.55+0.45*sin(t*1.6+sh*90.0);
      col += vec3(0.75,0.85,1.0)*st*tw*smoothstep(0.05,0.40,rd.y)*(sh-0.972)*22.0;
    }
  }

  float hitT = 1e5;
  /* stazione più alta a destra — corsia di cielo libera dai palazzi */
  vec3 stationPos = vec3(32.5, 19.5, -110.0);

  /* C. landa Encelado — piano ghiaccio */
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
      vec3 gc = vec3(0.12,0.14,0.18);
      gc = mix(gc, vec3(0.06,0.08,0.12), crack*0.75);
      gc += vec3(0.15,0.22,0.30)*crack2*0.35;
      vec3 nApprox = normalize(vec3(crack*0.4-0.2, 1.0, crack2*0.3));
      float spec = pow(max(dot(nApprox, satDir),0.0), 8.0);
      gc += vec3(0.45,0.42,0.38)*spec*0.25;
      float fogA = 1.0-exp(-tg*0.025);
      col = mix(gc, fogCol, fogA);
      hitT = tg;
    }
  }

  /* heightfield ridge mid-ground (sotto l’orizzonte) */
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
        vec3 rc = mix(vec3(0.10,0.12,0.16), vec3(0.18,0.20,0.24), slope);
        float crev = smoothstep(0.04,0.0,abs(fract(rp.x*0.35)-0.5)-0.46);
        rc = mix(rc, vec3(0.05,0.07,0.10), crev*0.7);
        float fogA = 1.0-exp(-tr*0.022);
        col = mix(rc, fogCol, fogA);
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
        float pulse = 0.75+0.25*sin(t*0.55+float(i)*2.4);
        col += vec3(0.45,0.65,0.95)*g*vfade*0.16*pulse;
      }
    }
  }

  /* D. stazione orbitale — hub + pannelli (silhouette metallica, non anello glow) */
  if(rd.z < -0.01 && rd.y > -0.02){
    float ts = (stationPos.z-ro.z)/rd.z;
    if(ts>0.0 && ts<hitT){
      vec3 sp = ro+rd*ts;
      vec2 uv = (sp.xy - stationPos.xy) * 0.085;
      if(length(uv) < 2.2){
        vec2 a = abs(uv);
        /* hub centrale */
        float hub = max(a.x-0.28, a.y-0.20);
        hub = max(hub, max(a.x*0.6+a.y*0.35, a.y)-0.26);
        /* spine di docking */
        float spine = max(a.x-0.06, a.y-0.70);
        /* bracci */
        float arm = max(abs(uv.y)-0.05, abs(abs(uv.x)-0.55)-0.22);
        /* pannelli solari */
        float panel = max(abs(uv.y)-0.14, abs(abs(uv.x)-1.15)-0.48);
        float strut = max(abs(uv.y)-0.025, abs(abs(uv.x)-0.70)-0.12);
        float body = min(min(hub, spine), min(arm, min(panel, strut)));
        float mask = smoothstep(0.035, -0.01, body);
        if(mask > 0.01){
          vec3 metal = vec3(0.22,0.26,0.32);
          float litWin = step(0.55, hash21(floor(uv*14.0)))
                       * smoothstep(0.08,0.0,hub+0.02)
                       * (0.55+0.45*sin(t*1.8+uv.x*6.0));
          float panelLine = smoothstep(0.02,0.0,abs(fract(uv.x*3.5)-0.5)-0.42)
                          * smoothstep(0.05,0.0,panel);
          vec3 sc = metal * mask;
          sc += vec3(0.35,0.75,1.0)*litWin*0.9;
          sc += vec3(0.15,0.25,0.40)*panelLine*mask;
          sc += vec3(0.5,0.85,1.0)*smoothstep(0.06,0.0,abs(spine+0.02))*0.35
              * (0.6+0.4*sin(t*3.0));
          float fogA = 1.0-exp(-ts*0.010);
          col = mix(col, mix(sc, fogCol, fogA*0.35), clamp(mask,0.,1.));
        }
      }
    }
  }

  /* E. metropoli — skyline BASSO sull’orizzonte (non riempie il frame)
     Composizione: ~40% basso = città+landa; alto = cielo/Saturno/stazione.
     Skip se il raggio guarda troppo in alto. */
  if(rd.z < -0.02 && rd.y < 0.12){
    for(int i=0;i<4;i++){
      float fi = float(i);
      /* lontana: sotto l’orizzonte, non a pochi metri dalla finestra */
      float lz = -(28.0 + fi*16.0);
      float tt = (lz-ro.z)/rd.z;
      if(tt<0. || tt>hitT) continue;
      vec3 p = ro + rd*tt;

      /* corridoio sinistro per Saturno; destro alto già protetto da rd.y */
      float sideClear = smoothstep(-10.0,-2.0,p.x); /* meno densità a sinistra */
      float bw = 2.4 + fi*2.0;
      float xx = p.x/bw + fi*5.17;
      float id = floor(xx);
      float fx = fract(xx);
      float hh = hash21(vec2(id,fi));
      /* ~45% celle vuote + rarefazione a sinistra */
      float gap = step(0.45, hash21(vec2(id*3.1, fi+9.0))*sideClear);
      /* altezze contenute: skyline, non canyon urbano */
      float bh = (0.55 + hh*hh*3.8 + fi*0.55)*gap;
      /* hard cap: non salire nel cielo di Saturno */
      bh = min(bh, 4.2 - fi*0.35);
      if(bh < 0.15) continue;

      float typeH = hash21(vec2(id*1.7, fi*4.2));
      float typ = floor(typeH*4.0);

      float silhouette = 0.0;
      if(typ < 0.5){
        silhouette = step(p.y, bh)*step(-2.5, p.y);
      } else if(typ < 1.5){
        float setBh = bh * (1.0 - 0.28*step(0.5, abs(fx-0.5)*2.0));
        if(p.y > bh*0.55) setBh = bh * (0.55 + 0.20*step(0.35,fx)*step(fx,0.65));
        silhouette = step(p.y, setBh)*step(-2.5, p.y);
      } else if(typ < 2.5){
        float py = bh * max(0.0, 1.0 - abs(fx-0.5)*1.7);
        silhouette = step(p.y, py)*step(-2.5, p.y);
      } else {
        float twin = step(0.16, abs(fx-0.5));
        silhouette = twin * step(p.y, bh)*step(-2.5, p.y);
      }

      float bridge = 0.0;
      if(fi>0.5 && fi<2.5 && hash21(vec2(id,fi+40.0))>0.94){
        float by = 1.2 + hh*1.5;
        bridge = step(abs(p.y-by),0.08)*step(abs(fx-0.5),0.55)*step(by, bh);
      }

      float edge = smoothstep(0.02,0.08,fx)*smoothstep(0.98,0.92,fx);
      if((silhouette>0.5 && edge>0.5) || bridge>0.5){
        hitT = tt;
        vec3 base = vec3(0.04,0.05,0.08)*(1.0+fi*0.45);
        vec2 wuv = vec2(p.x/0.28, p.y/0.18);
        vec2 wid = floor(wuv);
        vec2 wf  = fract(wuv);
        float lit = step(hash21(wid+id*0.37), 0.38);
        float wm  = step(0.26,wf.x)*step(wf.x,0.74)*step(0.20,wf.y)*step(wf.y,0.80);
        float wh = hash21(wid*1.71+3.0);
        vec3 wc = wh<0.35 ? vec3(0.35,0.45,1.0) :
                  wh<0.62 ? vec3(0.15,0.75,1.0) :
                  wh<0.85 ? vec3(0.70,0.85,1.0) : vec3(0.85,0.40,1.0);
        float flick = 0.80+0.20*sin(t*2.5+hash21(wid)*40.0);
        vec3 c = base + wc*lit*wm*flick*1.45;
        c += base*bridge*2.0 + vec3(0.2,0.5,0.8)*bridge*0.8;

        if(typ > 0.5){
          c += vec3(0.6,0.85,1.0)*smoothstep(0.18,0.0,abs(p.y-bh+0.06))
               *step(abs(fx-0.5),0.06)*(0.5+0.5*sin(t*3.0+id));
        } else {
          c += vec3(1.0,0.25,0.55)*smoothstep(0.14,0.0,abs(p.y-bh+0.08))
               *step(0.70,hash21(vec2(id,5.0)))*(0.5+0.5*sin(t*2.5+id*3.0));
        }

        if(hash21(vec2(id,33.0+fi))>0.82 && bh>2.2){
          vec2 suv = (p.xy - vec2((id-fi*5.17+0.5)*bw, bh*0.55))/vec2(bw*0.28, 0.7);
          float sign = step(abs(suv.x),1.0)*step(abs(suv.y),1.0);
          float sflick = step(0.12, fract(sin(floor(t*8.0)*12.9+id)*43.75));
          float sh2 = hash21(vec2(id,2.0));
          vec3 scol = sh2<0.40 ? vec3(0.2,0.85,1.0) :
                      sh2<0.75 ? vec3(0.7,0.35,1.0) : vec3(1.0,0.55,0.25);
          float pat = 0.55+0.45*sin(suv.y*18.0+suv.x*5.0+t);
          c += scol*sign*sflick*pat*2.2;
        }

        float fogA = 1.0-exp(-tt*0.022);
        col = mix(c, fogCol, fogA);
        break;
      }
    }
  }

  /* navi: piccole astronavi (fusoliera + ali + scia motore) */
  if(rd.z<-0.01){
    for(int i=0;i<6;i++){
      float fi = float(i);
      float seed = hash11(fi*13.7);
      float speed = 0.07 + seed*0.10;
      float phase = fract(t*speed + seed);
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
      if(length(cross(fw, vec3(0.,1.,0.))) < 0.08)
        rt = normalize(cross(fw, vec3(1.,0.,0.)));
      vec3 upv = cross(rt, fw);

      float dist = length(sp-ro);
      vec3 dShip = (sp-ro)/dist;
      float scl = 0.55 + seed*0.25;
      float maxAng = 2.2*scl/dist;
      if(acos(clamp(dot(rd,dShip),-1.,1.)) > maxAng) continue;
      float tp = dist / max(dot(rd,dShip), 0.2);
      if(tp<0.0 || tp>hitT) continue;
      vec3 hp = ro + rd*tp;
      vec3 q = hp - sp;
      float along = dot(q, fw)/scl;
      float side  = dot(q, rt)/scl;
      float vert  = dot(q, upv)/scl;
      vec2 p2 = vec2(along, side);

      /* fusoliera a diamante allungato */
      float halfL = 0.85;
      float fuseW = 0.13 * (1.0 - abs(along)/halfL);
      float fuse = max(abs(along)-halfL, abs(side)-fuseW);
      fuse = max(fuse, abs(vert)-0.08);
      /* ali a delta */
      float wingSpan = 0.55 * clamp(1.0 - (along+0.15)/0.7, 0.0, 1.0);
      float wing = max(abs(along+0.05)-0.35, abs(side)-wingSpan);
      wing = max(wing, abs(vert)-0.03);
      /* coda / pinna */
      float fin = max(abs(along+0.55)-0.18, abs(side)-0.04);
      fin = max(fin, abs(vert)-0.16*(1.0-abs(along+0.55)/0.18));

      float hull = min(fuse, min(wing, fin));
      float mask = smoothstep(0.04, -0.01, hull);
      if(mask < 0.01) continue;

      vec3 bodyCol = mix(vec3(0.55,0.62,0.72), vec3(0.35,0.40,0.48), seed);
      float canopy = smoothstep(0.12,0.0, length(vec2(along-0.25, side)*vec2(1.4,2.2)))
                   * step(abs(vert),0.1);
      vec3 hue = bodyCol*mask;
      hue += vec3(0.25,0.55,0.85)*canopy*0.8;
      /* motore: solo in coda */
      float eng = smoothstep(0.22,0.0, length(vec2(along+0.78, side)*vec2(1.6,2.5)))
                * step(along, -0.55);
      vec3 exhaust = mix(vec3(0.4,0.85,1.0), vec3(1.0,0.55,0.25), step(0.75,seed));
      hue += exhaust*eng*(1.1+0.4*sin(t*20.0+fi*5.0));
      /* scia corta dietro */
      for(int k=1;k<=3;k++){
        float fk = float(k);
        vec3 trailP = sp - fw*scl*(0.5+fk*0.55);
        vec3 dt = normalize(trailP-ro);
        float dang = 1.0-dot(rd,dt);
        hue += exhaust * 0.000008/(0.000002+dang*dang*8.0) * (1.0-fk*0.28);
      }
      col += hue * 1.15;
    }
  }

  return col;
}

/* ============================================================
   UI DEL TABLET (procedurale, emissiva)
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
    float scan = 0.55+0.45*sin(uv.y*70.0 - t*14.0);
    c *= 0.75+0.45*scan;
    float hx = abs(fract(uv.x*9.0)-0.5);
    float hy = abs(fract(uv.y*14.0+t*0.4)-0.5);
    float hex = smoothstep(0.48,0.42,max(hx*1.2,hy));
    c += vec3(0.2,0.85,1.0)*hex*0.18;
    float ang = atan(uv.y+0.05, uv.x+0.15);
    float rad = length(uv-vec2(-0.15,-0.05));
    float sweep = smoothstep(0.12,0.0,abs(fract(ang/6.2831853 - t*0.45)-0.5)-0.42);
    c += vec3(0.35,0.9,1.0)*sweep*smoothstep(0.55,0.15,rad)*0.55;
    float col = floor((uv.x+1.0)*8.0);
    float rain = fract(uv.y*4.0 + t*1.8 + hash11(col*7.3)*4.0);
    float glyph = step(0.82,rain)*step(abs(uv.x),0.95)*step(uv.y,-0.75);
    c += vec3(0.25,1.0,0.75)*glyph*0.45;
    float br = step(0.88,abs(uv.x))*step(0.82,abs(uv.y));
    c += vec3(0.7,0.35,1.0)*br*(0.5+0.5*sin(t*6.0));
    float glitch = step(0.97,hash11(floor(t*18.0))) * step(0.4,hash21(floor(uv*vec2(40.0,12.0))+vec2(floor(t*18.0))));
    c = mix(c, vec3(c.b,c.g,c.r)*vec3(1.2,0.6,1.4), glitch*0.65);
    c *= 1.15+0.2*sin(t*5.0);
  }
  return c;
}

/* ============================================================
   SHADING
   ============================================================ */
vec3 shade(vec3 pos, vec3 rd, float mid){
  float t = iTime;
  float hovT = uHover==1.0?1.0:0.0;
  float hovB = uHover==2.0?1.0:0.0;
  float focT = uActive==1.0?1.0:0.0;
  float focB = uActive==2.0?1.0:0.0;
  float focO = uActive==3.0?1.0:0.0;

  /* emissivi puri — niente normali / AO / ombre */
  if(mid==7.0){
    vec3 tp = pos - TAB_C;
    tp.yz = rot2(0.5)*tp.yz;
    vec2 uv = vec2(tp.x/0.185, -tp.z/0.125);
    return tabletUI(uv, hovT, focT)*2.6;
  }
  if(mid==12.0) return vec3(0.35,0.55,0.75)*(0.4+0.08*sin(t*0.8));
  if(mid==13.0) return vec3(0.45,0.25,0.75)*1.6;
  if(mid==14.0) return vec3(0.22,0.45,0.7)*(1.2+0.15*sin(t*1.2+pos.x*2.0));
  if(mid==27.0){
    float steady = 0.55+0.15*sin(t*0.7+pos.x*2.0);
    return vec3(0.15,0.45,0.6)*steady*1.1;
  }
  /* social orbs — emissivi puri, luminosi, zero dipendenza da luci/AO */
  if(mid>=30.0 && mid<37.0){
    int oi = int(mid-30.0);
    vec3 ca = socialColorA(oi), cb = socialColorB(oi);
    vec3 op = socialPos(oi);
    vec3 lp = pos - op;
    float r = 0.090;
    vec3 nA = lp / max(length(lp), 1e-4);
    float lat = clamp(lp.y / r, -1.0, 1.0);
    float lon = atan(lp.z, lp.x);
    float swirl = 0.5 + 0.5*sin(lat*4.5 + lon*2.0 + t*(1.2+float(oi)*0.25));
    vec3 hue = mix(ca, cb, swirl);
    float ring = smoothstep(0.14, 0.0, abs(lat - 0.2*sin(t*0.9+float(oi))));
    float hov = (uHover==8.0+float(oi)) ? 1.0 : 0.0;
    /* glow costante + alone verso camera (desk a -X) */
    float glow = 1.35 + 0.45*max(-nA.x, 0.0);
    vec3 c = hue * glow + hue * ring * 0.85 + mix(ca, cb, 0.5) * 0.45;
    c += vec3(1.0) * (0.08 + 0.12*hov);
    c *= 1.15 + hov * 0.9;
    return c;
  }

  vec3 n = calcNormal(pos);
  vec3 v = -rd;
  float fres = pow(1.0-max(dot(n,v),0.0),3.0);

  if(mid==18.0){
    float pulse = 0.6+0.4*sin(t*4.0);
    float scan = 0.7+0.3*sin(pos.y*160.0-t*10.0);
    return vec3(0.2,0.9,1.0)*pulse*scan*2.2 + vec3(0.3,0.2,1.0)*fres*2.0;
  }
  if(mid==10.0||mid==11.0){
    vec3 hue = mid==10.0 ? vec3(0.65,0.25,1.0) : vec3(0.15,0.65,1.0);
    float core = 0.5+0.5*sin(pos.y*40.0+t*2.0);
    vec3 c = hue*(0.7+0.9*fres) + hue*core*0.35 + hue*hovB*0.8;
    if(focB>0.5){
      float aura = 0.55+0.45*sin(t*5.0+pos.y*30.0);
      float ring = smoothstep(0.08,0.0,abs(fract(pos.y*18.0-t*2.5)-0.5)-0.38);
      float lift = 0.5+0.5*sin(t*3.2+pos.x*20.0+pos.z*17.0);
      c += hue*aura*0.55 + hue*ring*0.7 + hue*lift*0.35;
      c *= 1.15+0.2*sin(t*4.0);
    }
    return c;
  }
  if(mid>=20.0 && mid<24.0){
    int oi = int(mid-20.0);
    vec3 ca = uOrbA[oi], cb = uOrbB[oi];
    vec3 op = orbPos(oi);
    vec3 lp = pos-op;
    float r = uOrbR[oi];
    float lat = lp.y/r;
    float lon = atan(lp.z,lp.x);
    float swirl = sin(lat*6.0 + lon*2.0 + t*(1.2+float(oi)*0.35));
    vec3 hue = mix(ca, cb, 0.5+0.5*swirl);
    float ring = smoothstep(0.10,0.0,abs(lat-sin(t*0.9+float(oi)*2.1)*0.5));
    float hov = (uHover==4.0+float(oi))?1.0:0.0;
    float act = (uActive==4.0+float(oi))?1.0:0.0;
    vec3 c = hue*(0.55+1.1*fres) + hue*ring*0.7 + mix(ca,cb,0.5)*0.25;
    c *= 0.85+0.15*sin(t*5.0+lat*20.0);
    if(act>0.5){
      float shell = pow(fres, 1.2)*(0.6+0.4*sin(t*6.0+lon*4.0));
      float band = smoothstep(0.07,0.0,abs(fract(lon/6.2831853*3.0 - t*0.8)-0.5)-0.4);
      float spark = step(0.92, hash11(floor(lat*12.0)+floor(lon*8.0)+floor(t*10.0)));
      float pulse = 0.5+0.5*sin(t*4.5);
      c += mix(ca,cb,0.5)*shell*1.4 + hue*band*0.9 + vec3(1.0)*spark*0.55;
      c *= 1.2+0.35*pulse;
    }
    return c*(1.1+hov*1.2+act*0.5);
  }
  if(mid==24.0){
    float hovO = uHover==3.0?1.0:0.0;
    vec3 q = octToLocal(pos-OCT_C);
    vec3 alb = mix(vec3(0.62,0.22,1.00), vec3(0.38,0.12,0.82), clamp(q.y*6.0+0.2,0.,1.));
    vec3 hq = q - vec3(0.,0.085+0.008*sin(t*2.0),0.);
    float eyeL = length(hq-vec3(0.026,0.012,0.052));
    float eyeR = length(hq-vec3(-0.026,0.012,0.052));
    vec3 emis = vec3(0.0);
    if(eyeL < 0.007 || eyeR < 0.007) alb = vec3(0.02);
    else if(eyeL < 0.016 || eyeR < 0.016) alb = vec3(0.95);
    emis += vec3(0.45,0.25,1.0)*smoothstep(0.008,0.0,abs(fract(atan(q.z,q.x)*3.0)-0.5)-0.35)
            *step(q.y,0.03)*0.25;
    if(focO>0.5){
      float circuit = smoothstep(0.04,0.0,abs(fract(atan(q.z,q.x)*4.0 + t*1.5)-0.5)-0.42);
      float pulse = 0.5+0.5*sin(t*7.0+q.y*40.0);
      float halo = pow(fres,1.5)*(0.7+0.3*sin(t*5.0));
      emis += vec3(0.55,0.3,1.0)*circuit*pulse*0.85;
      emis += vec3(0.4,0.85,1.0)*halo*0.9;
      if(eyeL < 0.016 || eyeR < 0.016) emis += vec3(0.3,0.9,1.0)*(0.4+0.6*sin(t*8.0));
    }
    float dif = max(dot(n, normalize(vec3(0.3,0.8,-0.4))),0.0);
    float spe = pow(max(dot(n,normalize(normalize(vec3(0.3,0.8,-0.4))+v)),0.0),30.0);
    vec3 c = alb*(0.35+0.75*dif) + vec3(1.0,0.9,0.8)*spe*0.8 + emis;
    c += vec3(0.75,0.45,1.0)*fres*0.35;
    c += alb*hovO*0.9;
    if(focO>0.5) c *= 1.1+0.15*sin(t*4.5);
    return c;
  }

  /* ----- albedo ----- */
  vec3 alb = vec3(0.05);
  float gloss = 0.0;
  vec3 emis = vec3(0.0);

  if(mid==2.0){ /* stanza — habitat Enceladus */
    if(n.y>0.9){ /* pavimento */
      alb = vec3(0.07,0.075,0.09);
      gloss = 0.55;
      vec2 gp = pos.xz*0.55;
      float seam = max(
        smoothstep(0.04,0.0,abs(fract(gp.x)-0.5)-0.46),
        smoothstep(0.04,0.0,abs(fract(gp.y)-0.5)-0.46)
      );
      alb = mix(alb, vec3(0.04,0.045,0.055), seam*0.7);
      float hex = abs(fract(pos.x*0.35+pos.z*0.2)-0.5)+abs(fract(pos.z*0.35-pos.x*0.15)-0.5);
      alb *= 0.92+0.08*smoothstep(0.55,0.35,hex);
      emis += vec3(0.15,0.35,0.55)*seam*0.04;
      float frost = smoothstep(0.15,0.0,abs(pos.z+2.8))*0.08;
      alb += vec3(0.04,0.07,0.10)*frost;
      /* strip centrale (ex SDF mid 25) */
      float strip = step(abs(pos.x),0.35)*step(abs(pos.z-0.2),2.2);
      alb = mix(alb, vec3(0.08,0.085,0.10), strip*0.85);
      gloss = mix(gloss, 0.45, strip);
      emis += vec3(0.12,0.28,0.38)*strip*0.06;
    } else if(n.y<-0.9){ /* soffitto */
      alb = vec3(0.08,0.085,0.10);
      float pan = step(0.92,fract(pos.x*0.55))+step(0.92,fract(pos.z*0.55));
      alb *= 1.0-0.45*clamp(pan,0.,1.);
      float recess = smoothstep(0.08,0.0,abs(abs(pos.x)-1.9)-0.15)*smoothstep(2.2,0.0,abs(pos.z+0.5));
      emis += vec3(0.25,0.40,0.55)*recess*0.12;
    } else { /* pareti */
      alb = vec3(0.09,0.095,0.115);
      gloss = 0.18;
      float vSeam = smoothstep(0.035,0.0,abs(fract(pos.y*0.85)-0.5)-0.47);
      float hSeam = smoothstep(0.035,0.0,abs(fract((pos.x+pos.z)*0.45)-0.5)-0.47);
      float seam = max(vSeam, hSeam);
      alb = mix(alb, vec3(0.05,0.055,0.07), seam*0.85);
      float plate = smoothstep(0.12,0.0,abs(fract(pos.y*0.42)-0.5)-0.38);
      alb *= 0.88+0.12*plate;

      /* brina / patina fredda vicino alla finestra */
      float cold = smoothstep(-2.5,-3.5,pos.z)*0.12;
      alb += vec3(0.03,0.06,0.09)*cold;

      /* rivetti strutturali */
      vec2 rivUV = vec2(pos.y*2.2, (pos.x+pos.z)*1.6);
      float riv = smoothstep(0.07,0.02,length(fract(rivUV)-0.5));
      alb = mix(alb, vec3(0.16,0.17,0.20), riv*0.55*seam);

      /* conduit lines — dim, steady */
      float conduit = smoothstep(0.012,0.0,abs(fract(pos.y*1.1+0.25)-0.5)-0.48);
      emis += vec3(0.12,0.28,0.42)*conduit*0.06;

      /* status ticks (molto tenui, quasi statici) */
      float tick = step(0.97,fract(pos.y*3.5+hash11(floor(pos.z*2.0))*0.3));
      emis += vec3(0.2,0.55,0.7)*tick*conduit*0.15;

      /* parete sinistra: texture fredda dietro le mensole */
      if(pos.x<-3.55){
        float rib = smoothstep(0.04,0.0,abs(fract(pos.z*0.55)-0.5)-0.46);
        alb = mix(alb, vec3(0.06,0.07,0.09), rib*0.5);
        float frostL = 0.04+0.03*sin(pos.z*8.0+pos.y*3.0);
        alb += vec3(0.02,0.05,0.07)*frostL;
      }

      /* parete destra: texture neutra dietro orbs social */
      if(pos.x>3.55){
        float rib = smoothstep(0.04,0.0,abs(fract(pos.z*0.5)-0.5)-0.46);
        alb = mix(alb, vec3(0.055,0.06,0.075), rib*0.4);
      }

      /* parete dietro: porta di servizio / sigilli */
      if(pos.z>2.7){
        float door = smoothstep(0.9,0.7,abs(pos.x))*smoothstep(0.9,0.55,abs(pos.y-1.5));
        alb = mix(alb, vec3(0.06,0.065,0.08), door*0.6);
        float seal = smoothstep(0.025,0.0,abs(abs(pos.x)-1.05))*smoothstep(1.2,0.0,abs(pos.y-1.5));
        emis += vec3(0.3,0.55,0.5)*seal*0.2;
        float idPlate = step(abs(pos.x+2.2),0.35)*step(abs(pos.y-2.55),0.12);
        emis += vec3(0.2,0.45,0.6)*idPlate*0.3;
      }

      /* cornice finestra — alone freddo */
      if(pos.z<-3.5){
        float winEdge = smoothstep(0.28,0.0,abs(abs(pos.x)-WIN_B.x))*smoothstep(0.28,0.0,abs(abs(pos.y-WIN_C.y)-WIN_B.y));
        emis += vec3(0.2,0.45,0.7)*winEdge*0.18;
      }
    }
  }
  else if(mid==4.0){ alb=vec3(0.14,0.14,0.16); gloss=0.85; }
  else if(mid==5.0){ alb=vec3(0.09,0.09,0.11); gloss=0.2; }
  else if(mid==6.0){
    alb=vec3(0.03,0.03,0.04); gloss=0.5;
    if(focT>0.5){
      emis += vec3(0.45,0.25,1.0)*(0.35+0.35*sin(t*5.0))*pow(fres,2.0);
      emis += vec3(0.2,0.8,1.0)*0.25*(0.5+0.5*sin(t*7.0+pos.x*40.0));
    }
  }
  else if(mid==8.0){ /* scacchiera */
    alb=vec3(0.04,0.038,0.07); gloss=0.5;
    vec3 bp = pos-BRD_C;
    if(n.y>0.9 && abs(bp.x)<0.22 && abs(bp.z)<0.22){
      vec2 cell = floor(bp.xz/0.055+4.0);
      float chk = mod(cell.x+cell.y,2.0);
      alb = mix(vec3(0.02,0.018,0.045), vec3(0.10,0.095,0.15), chk);
      vec2 cf = abs(fract(bp.xz/0.055+4.0)-0.5);
      float gl = smoothstep(0.5,0.45,max(cf.x,cf.y));
      emis += vec3(0.3,0.5,1.0)*(1.0-gl)*0.5;
      if(focB>0.5){
        float pulse = 0.5+0.5*sin(t*4.0+cell.x+cell.y*1.7);
        emis += mix(vec3(0.55,0.25,1.0),vec3(0.15,0.75,1.0),chk)*pulse*(1.0-gl)*0.85;
        float beam = smoothstep(0.08,0.0,abs(fract(bp.x*6.0+bp.z*6.0 - t*1.2)-0.5)-0.42);
        emis += vec3(0.3,0.9,1.0)*beam*0.35;
      }
    }
    float rim = smoothstep(0.015,0.0,abs(max(abs(bp.x),abs(bp.z))-0.235))*step(0.,n.y);
    emis += vec3(0.55,0.25,1.0)*rim*(0.9+0.6*sin(t*2.5))*(1.0+hovB*2.0);
    if(focB>0.5){
      float chase = fract(atan(bp.z,bp.x)/6.2831853 + t*0.55);
      float gate = smoothstep(0.12,0.0,abs(chase-0.5)-0.38);
      emis += vec3(0.4,0.85,1.0)*rim*gate*2.2;
      emis += vec3(0.7,0.35,1.0)*rim*(0.5+0.5*sin(t*6.0));
    }
  }
  else if(mid==15.0){ alb=vec3(0.30,0.28,0.30); gloss=0.05; }
  else if(mid==17.0){
    alb=vec3(0.06,0.06,0.08); gloss=0.4;
    vec3 mp = pos-vec3(1.18,0.85,0.60);
    emis += vec3(0.6,0.3,1.0)*smoothstep(0.012,0.0,abs(mp.y-0.055))*0.9;
    float logo = smoothstep(0.03,0.02,length(vec2(atan(mp.x,mp.z)*0.045, mp.y+0.01)));
    emis += vec3(0.3,0.7,1.0)*logo*0.6;
  }
  else if(mid==25.0){ /* tubi / rack metallo scuro */
    alb = vec3(0.08,0.085,0.10);
    gloss = 0.45;
    emis += vec3(0.15,0.3,0.4)*pow(fres,2.5)*0.15;
  }
  else if(mid==26.0){ /* box / bulkhead */
    alb = vec3(0.06,0.065,0.08);
    gloss = 0.25;
    float edge = pow(fres, 3.0);
    emis += vec3(0.12,0.25,0.35)*edge*0.2;
  }
  else if(mid==28.0){ /* display / griglia */
    alb = vec3(0.03,0.04,0.05);
    gloss = 0.1;
    float lines = max(
      smoothstep(0.03,0.0,abs(fract(pos.y*18.0)-0.5)-0.46),
      smoothstep(0.03,0.0,abs(fract(pos.z*14.0+pos.x*14.0)-0.5)-0.46)
    );
    emis += vec3(0.2,0.55,0.7)*lines*0.35;
    emis += vec3(0.1,0.3,0.4)*(0.3+0.2*sin(t*0.5+pos.y*4.0));
  }
  else if(mid==40.0){ /* piante aliene */
    alb = vec3(0.08,0.18,0.10);
    gloss = 0.35;
    float vein = smoothstep(0.04,0.0,abs(fract(pos.y*12.0+pos.z*8.0)-0.5)-0.44);
    float pulse = 0.55+0.45*sin(t*1.8+pos.y*6.0);
    emis += mix(vec3(0.25,0.9,0.45), vec3(0.7,0.25,1.0), vein)*pulse*0.55;
    emis += vec3(0.4,0.85,0.55)*pow(fres,2.0)*0.4;
  }
  else if(mid==41.0){ /* armi */
    alb = vec3(0.12,0.13,0.15);
    gloss = 0.75;
    emis += vec3(0.3,0.55,0.75)*pow(fres,3.0)*0.25;
    float edge = pow(fres, 4.0);
    emis += vec3(0.15,0.7,1.0)*edge*0.35;
  }
  else if(mid==42.0){ /* tech gear */
    alb = vec3(0.05,0.06,0.08);
    gloss = 0.4;
    float panel = step(0.82,fract(pos.y*20.0+pos.z*12.0));
    emis += vec3(0.2,0.7,1.0)*panel*0.55;
    emis += vec3(0.35,0.55,1.0)*(0.25+0.2*sin(t*3.0+pos.z*8.0));
  }

  /* ----- illuminazione ----- */
  float ao = calcAO(pos,n);
  vec3 col = vec3(0.0);

  /* luce dalla finestra */
  vec3 Lw = normalize(vec3(0.12,0.35,-1.0));
  float ndl = max(dot(n,Lw),0.0);
  float sh = ndl < 0.05 ? 0.0 : softShadow(pos+n*0.02, Lw);
  col += alb * ndl * sh * vec3(0.75,0.85,1.05) * 2.4;

  /* ambiente */
  col += alb * (0.45+0.35*n.y) * vec3(0.30,0.30,0.42) * ao;
  col += alb * max(-n.z,0.0) * vec3(0.30,0.32,0.50) * ao;

  /* luci puntiformi (4) */
  {
    vec3 lps[4];
    vec3 lcs[4];
    lps[0]=vec3(-1.9,3.1,-0.5); lcs[0]=vec3(0.55,0.70,1.0)*2.4;
    lps[1]=vec3( 1.9,3.1,-0.5); lcs[1]=vec3(0.55,0.70,1.0)*2.4;
    lps[2]=vec3( 0.0,0.70,1.40); lcs[2]=vec3(0.6,0.3,1.0)*1.1;
    lps[3]=vec3(-1.55,1.00,0.55); lcs[3]=vec3(1.0,0.55,0.22)*0.9;
    for(int i=0;i<4;i++){
      vec3 ld = lps[i]-pos;
      float dist = length(ld); ld/=dist;
      float att = 1.0/(1.0+dist*dist*1.1);
      float dif = max(dot(n,ld),0.0);
      vec3 hv = normalize(ld+v);
      float spe = pow(max(dot(n,hv),0.0), 48.0)*gloss;
      col += (alb*dif + spe*1.8) * lcs[i]*att*ao;
    }
  }

  /* riflessi della città su pavimento e scrivania */
  if(gloss>0.4){
    vec3 rr = reflect(rd,n);
    if(rr.z<-0.05){
      float tw = (WIN_C.z-pos.z)/rr.z;
      if(tw>0.0){
        vec3 wp = pos+rr*tw;
        if(abs(wp.x-WIN_C.x)<WIN_B.x && abs(wp.y-WIN_C.y)<WIN_B.y){
          vec3 rc = renderCity(pos,rr);
          col += rc*(0.10+0.55*fres)*gloss;
        }
      }
    }
    col += vec3(0.3,0.25,0.7)*fres*gloss*0.08;
  }

  col += emis;
  return col;
}

/* ============================================================
   MAIN
   ============================================================ */
void main(){
  vec2 frag = gl_FragCoord.xy;
  vec2 uv = (2.0*frag - iResolution)/iResolution.y;
  uv.x -= uViewBias * 0.50 * (iResolution.x / iResolution.y);
  float t = iTime;

  vec3 ro = uCamRo;
  vec3 fw = normalize(uCamTarget - uCamRo);
  vec3 rt = normalize(cross(fw, vec3(0.,1.,0.)));
  vec3 up = cross(rt,fw);
  vec3 rd = normalize(fw*uCamFocal + uv.x*rt + uv.y*up);

  vec2 hit = march(ro,rd);
  vec3 col;
  if(hit.y<0.0){
    col = renderCity(ro,rd);
    float tw = (WIN_C.z-ro.z)/rd.z;
    vec3 wp = ro+rd*tw;
    vec2 wuv = (wp.xy-WIN_C.xy)/WIN_B;
    float streak = smoothstep(0.35,0.0,abs(wuv.x-wuv.y*0.6+0.3))*0.025
                 + smoothstep(0.25,0.0,abs(wuv.x-wuv.y*0.6-0.55))*0.015;
    col += vec3(0.45,0.55,0.85)*streak;
    col *= 1.0-0.06*length(wuv*wuv);
  } else {
    vec3 pos = ro+rd*hit.x;
    col = shade(pos,rd,hit.y);
    col = mix(col, vec3(0.10,0.11,0.16), 1.0-exp(-hit.x*0.035));
  }

  fragColor = vec4(col,1.0);
}
