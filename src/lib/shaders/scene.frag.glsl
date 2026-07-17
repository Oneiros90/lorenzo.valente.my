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
const vec2 WIN_B = vec2(2.55,0.85);
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
  float xOff = (mod(fi, 2.0) < 0.5) ? -0.05 : 0.05;
  float r = uOrbR[i];
  return vec3(-0.22 + xOff, 0.795 + r + 0.015*sin(iTime*1.3+fi*1.9), z);
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

  /* cornice finestra (emissiva) */
  float fr = sdBox(p-vec3(0.,1.8,-3.66), vec3(2.66,0.96,0.05));
  fr = max(fr, -sdBox(p-vec3(0.,1.8,-3.66), vec3(2.52,0.82,0.3)));
  res = opU(res, vec2(fr,12.0));

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

  /* sfere olografiche aziende (fluttuanti su piedistalli) */
  for(int i=0;i<4;i++){
    vec3 op = orbPos(i);
    float r = uOrbR[i];
    res = opU(res, vec2(sdSphere(p-op, r), 20.0+float(i)));
    res = opU(res, vec2(sdCylinder(p-vec3(op.x,0.795,op.z), 0.010,0.035), 5.0));
    res = opU(res, vec2(sdCylinder(p-vec3(op.x,0.806,op.z), 0.003,0.030), 14.0));
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

  /* letto */
  vec3 ep = p - vec3(2.55,0.34,-1.6);
  res = opU(res, vec2(sdRoundBox(ep, vec3(1.0,0.13,1.15),0.06), 15.0));
  res = opU(res, vec2(sdBox(ep-vec3(0.,-0.22,0.), vec3(0.9,0.1,1.05)), 5.0));
  res = opU(res, vec2(sdBox(ep-vec3(0.,-0.13,0.), vec3(0.94,0.008,1.09)), 14.0)); // glow blu
  res = opU(res, vec2(sdRoundBox(ep-vec3(0.,0.14,-0.85), vec3(0.72,0.055,0.22),0.045), 15.0)); // cuscino

  /* neon soffitto */
  res = opU(res, vec2(sdBox(vec3(abs(p.x)-1.9,p.y-3.17,p.z+0.5), vec3(0.025,0.018,2.7)), 14.0));

  /* tazza + gadget olografico */
  res = opU(res, vec2(sdCylinder(p-vec3(1.18,0.85,0.60), 0.065,0.045), 17.0));
  res = opU(res, vec2(sdBox(p-vec3(-1.28,0.84,0.55), vec3(0.045,0.045,0.045)), 18.0));

  return res;
}

/* ---------- march / normali / AO / ombre ---------- */
vec2 march(vec3 ro, vec3 rd){
  float t=0.0, m=-1.0;
  for(int i=0;i<130;i++){
    vec2 h = map(ro+rd*t);
    if(h.x < 0.0006*t+0.0004){ m=h.y; break; }
    t += h.x*0.9;
    if(t>28.0){ m=-1.0; break; }
  }
  if(t>28.0) m=-1.0;
  return vec2(t,m);
}
vec3 calcNormal(vec3 p){
  vec2 e=vec2(0.0014,-0.0014);
  return normalize(e.xyy*map(p+e.xyy).x + e.yyx*map(p+e.yyx).x +
                   e.yxy*map(p+e.yxy).x + e.xxx*map(p+e.xxx).x);
}
float calcAO(vec3 p, vec3 n){
  float occ=0., sca=1.;
  for(int i=1;i<=5;i++){
    float h=0.02+0.11*float(i)/5.0;
    occ += (h-map(p+n*h).x)*sca;
    sca *= 0.72;
  }
  return clamp(1.0-2.2*occ,0.,1.);
}
float softShadow(vec3 ro, vec3 rd){
  float res=1.0, t=0.03;
  for(int i=0;i<20;i++){
    float h=map(ro+rd*t).x;
    res=min(res,9.0*h/t);
    t+=clamp(h,0.03,0.35);
    if(res<0.02||t>7.0) break;
  }
  return clamp(res,0.,1.);
}

/* ============================================================
   CITTÀ PROCEDURALE (vista dalla finestra)
   ============================================================ */
vec3 renderCity(vec3 ro, vec3 rd){
  float t = iTime;
  /* cielo chiaro e freddo */
  vec3 col = mix(vec3(0.50,0.58,0.78), vec3(0.10,0.16,0.36), clamp(rd.y*1.5+0.15,0.,1.));

  /* stelle (tenui, cielo luminoso) */
  if(rd.y>0.10){
    vec2 sph = vec2(atan(rd.x,-rd.z), asin(clamp(rd.y,-1.,1.)));
    vec2 sg = sph*160.0;
    vec2 sid = floor(sg);
    float sh = hash21(sid);
    if(sh>0.978){
      vec2 sf = fract(sg)-0.5;
      float st = smoothstep(0.18,0.0,length(sf));
      float tw = 0.6+0.4*sin(t*2.0+sh*80.0);
      col += vec3(0.8,0.85,1.0)*st*tw*smoothstep(0.10,0.35,rd.y)*(sh-0.978)*18.0;
    }
  }

  /* Saturno gigante */
  {
    vec3 sat = normalize(vec3(-0.42,0.40,-1.0));
    float ca = dot(rd,sat);
    float ang = acos(clamp(ca,-1.,1.));
    float disk = smoothstep(0.155,0.145,ang);
    if(disk>0.001){
      float band = 0.5+0.5*sin((rd.y-sat.y)*95.0);
      vec3 sc = mix(vec3(0.58,0.56,0.62), vec3(0.74,0.70,0.76), band);
      float shade = smoothstep(-0.14,0.14,(rd.x-sat.x)+0.05);
      col = mix(col, sc*(0.45+0.55*shade), disk);
    }
    vec3 rx = normalize(cross(sat, vec3(0.,1.,0.)));
    vec3 ry = normalize(cross(sat, rx))*0.28 + rx*0.0;
    vec3 v = rd - sat*ca;
    vec2 e = vec2(dot(v,rx)/0.30, dot(v, normalize(cross(sat,rx)))/0.075);
    float r = length(e);
    if(ang>0.13 && r>0.55 && r<1.05){
      float rb = 0.5+0.5*sin(r*55.0);
      float ring = smoothstep(0.55,0.62,r)*smoothstep(1.05,0.95,r);
      col += vec3(0.45,0.42,0.50)*ring*rb*0.55;
    }
  }

  /* grattacieli, 4 strati con parallasse */
  float hitT = 1e5;
  if(rd.z < -0.02){
    for(int i=0;i<4;i++){
      float fi = float(i);
      float lz = -(9.0 + fi*14.0);
      float tt = (lz-ro.z)/rd.z;
      if(tt<0.) continue;
      vec3 p = ro + rd*tt;
      float bw = 2.0 + fi*1.7;
      float xx = p.x/bw + fi*7.31;
      float id = floor(xx);
      float fx = fract(xx);
      float hh = hash21(vec2(id,fi));
      float gap = step(0.10, hash21(vec2(id*3.1, fi+9.0)));
      float bh = (1.5 + hh*hh*15.0 + fi*3.5)*gap;
      float edge = smoothstep(0.02,0.07,fx)*smoothstep(0.98,0.93,fx);
      if(p.y<bh && p.y>-3.0 && edge>0.5){
        hitT = tt;
        vec3 base = vec3(0.055,0.065,0.10)*(1.0+fi*0.7);
        vec2 wuv = vec2(p.x/0.30, p.y/0.22);
        vec2 wid = floor(wuv);
        vec2 wf  = fract(wuv);
        float lit = step(hash21(wid+id*0.37), 0.42);
        float wm  = step(0.28,wf.x)*step(wf.x,0.72)*step(0.22,wf.y)*step(wf.y,0.78);
        float wh = hash21(wid*1.71+3.0);
        vec3 wc = wh<0.30 ? vec3(0.45,0.30,1.0) :
                  wh<0.58 ? vec3(0.15,0.65,1.0) :
                  wh<0.82 ? vec3(1.0,0.85,0.60) : vec3(1.0,0.35,0.75);
        float flick = 0.78+0.22*sin(t*3.0+hash21(wid)*40.0);
        vec3 c = base + wc*lit*wm*flick*1.7;
        /* faro sul tetto */
        c += vec3(1.0,0.2,0.45)*smoothstep(0.18,0.0,abs(p.y-bh+0.12))
             *step(0.65,hash21(vec2(id,5.0)))*(0.5+0.5*sin(t*2.5+id*3.0));
        /* insegna al neon */
        if(hash21(vec2(id,33.0+fi))>0.78 && bh>4.0){
          vec2 suv = (p.xy - vec2((id-fi*7.31+0.5)*bw, bh*0.55))/vec2(bw*0.28, 1.1);
          float sign = step(abs(suv.x),1.0)*step(abs(suv.y),1.0);
          float sflick = step(0.15, fract(sin(floor(t*9.0)*12.9+id)*43.75));
          float sh2 = hash21(vec2(id,2.0));
          vec3 scol = sh2<0.34 ? vec3(1.0,0.20,0.80) :
                      sh2<0.67 ? vec3(0.15,0.85,1.0) : vec3(1.0,0.60,0.20);
          float pat = 0.55+0.45*sin(suv.y*18.0+suv.x*5.0+t);
          c += scol*sign*sflick*pat*3.0;
        }
        float fogA = 1.0-exp(-tt*0.030);
        col = mix(c, vec3(0.40,0.46,0.64), fogA);
        break;
      }
    }
  }

  /* suolo ghiacciato con griglia */
  if(hitT>9e4 && rd.y<-0.02){
    float tg = (-2.2-ro.y)/rd.y;
    if(tg>0.){
      vec3 gp = ro+rd*tg;
      float grid = max( smoothstep(0.06,0.0,abs(fract(gp.x*0.25)-0.5)-0.46),
                        smoothstep(0.06,0.0,abs(fract(gp.z*0.25)-0.5)-0.46) );
      vec3 gc = vec3(0.30,0.34,0.44) + vec3(0.4,0.3,1.0)*grid*0.30;   /* ghiaccio chiaro */
      float fogA = 1.0-exp(-tg*0.05);
      col = mix(gc, vec3(0.40,0.46,0.64), fogA);
      hitT = tg;
    }
  }

  /* pennacchi di ghiaccio all'orizzonte */
  if(hitT>60.0 && rd.z<-0.05){
    float tp2 = (-70.0-ro.z)/rd.z;
    vec3 pp = ro+rd*tp2;
    for(int i=0;i<2;i++){
      float px = float(i)*46.0-20.0;
      float g = exp(-pow((pp.x-px)*0.05,2.0));
      float vfade = smoothstep(28.0,2.0,pp.y)*smoothstep(-2.0,4.0,pp.y);
      col += vec3(0.35,0.5,0.85)*g*vfade*0.10*(0.8+0.2*sin(t*0.7+float(i)*3.0));
    }
  }

  /* navi in volo con scia */
  if(rd.z<-0.01){
    for(int i=0;i<7;i++){
      float fi=float(i);
      float depth = 11.0+fi*5.5;
      float dirS  = mod(fi,2.0)<1.0?1.0:-1.0;
      float speed = (2.0+hash11(fi)*4.0)*dirS;
      float range = 34.0;
      float sy = 2.2+hash11(fi*7.0)*8.5;
      float sx = mod(t*speed + hash11(fi*3.0)*range*2.0, range*2.0)-range;
      vec3 sp = vec3(sx, sy, -depth);
      float tproj = (sp.z-ro.z)/rd.z;
      if(tproj>0.0 && tproj<hitT){
        vec3 hue = mix(vec3(0.4,0.6,1.0), vec3(1.0,0.4,0.9), hash11(fi*13.0));
        for(int k=0;k<4;k++){
          vec3 tpos = sp - vec3(dirS*float(k)*0.55,0.,0.);
          vec3 dir = normalize(tpos-ro);
          float dd = 1.0-dot(rd,dir);
          float fall = 1.0-float(k)*0.24;
          col += hue * 0.000012/(0.0000015+dd*dd*4.0) * fall * 0.032;
        }
      }
    }
  }

  /* ologramma gigante */
  if(rd.z<-0.01){
    float th = (-17.0-ro.z)/rd.z;
    if(th>0.0 && th<hitT){
      vec3 hp = ro+rd*th;
      vec2 huv = hp.xy - vec2(-5.5,7.0);
      float head = length((huv-vec2(0.,2.3))*vec2(1.0,0.95))-0.62;
      vec2 bq = vec2(huv.x, max(abs(huv.y-0.4)-1.25,0.0));
      float body = length(bq)-0.85;
      float fig = min(head,body);
      float glow = smoothstep(0.22,-0.1,fig);
      float scan = 0.6+0.4*sin(hp.y*22.0-t*9.0);
      float flick = 0.82+0.18*sin(t*31.0)*sin(t*7.3);
      col += vec3(0.22,0.6,1.0)*glow*scan*flick*0.85;
      col += vec3(0.4,0.3,1.0)*smoothstep(1.4,-0.6,fig)*0.10;
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
  vec3 n = calcNormal(pos);
  vec3 v = -rd;
  float fres = pow(1.0-max(dot(n,v),0.0),3.0);
  float hovT = uHover==1.0?1.0:0.0;
  float hovB = uHover==2.0?1.0:0.0;
  float focT = uActive==1.0?1.0:0.0;
  float focB = uActive==2.0?1.0:0.0;
  float focO = uActive==3.0?1.0:0.0;

  /* ----- materiali emissivi puri ----- */
  if(mid==7.0){ /* schermo tablet */
    vec3 tp = pos - TAB_C;
    tp.yz = rot2(0.5)*tp.yz;
    vec2 uv = vec2(tp.x/0.185, -tp.z/0.125);
    return tabletUI(uv, hovT, focT)*2.6;
  }
  if(mid==12.0) return vec3(0.60,0.50,0.95)*(0.55+0.10*sin(t*1.5));
  if(mid==13.0) return vec3(0.7,0.25,1.0)*2.8;
  if(mid==14.0) return vec3(0.18,0.5,1.0)*(2.4+0.4*sin(t*2.0+pos.x*2.0));
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

  if(mid==2.0){ /* stanza */
    if(n.y>0.9){ /* pavimento */
      alb = vec3(0.11,0.11,0.13);
      gloss = 0.75;
      float gr = max( smoothstep(0.03,0.0,abs(fract(pos.x*0.9)-0.5)-0.47),
                      smoothstep(0.03,0.0,abs(fract(pos.z*0.9)-0.5)-0.47) );
      emis += vec3(0.35,0.25,0.9)*gr*0.08;
    } else if(n.y<-0.9){ /* soffitto */
      alb = vec3(0.12,0.12,0.14);
      float pan = step(0.94,fract(pos.x*0.7))+step(0.94,fract(pos.z*0.7));
      alb *= 1.0-0.5*clamp(pan,0.,1.);
    } else { /* pareti */
      alb = vec3(0.13,0.13,0.16);
      float pan = step(0.95,fract(pos.y*1.3))+step(0.95,fract((pos.x+pos.z)*0.8));
      emis += vec3(0.2,0.15,0.5)*clamp(pan,0.,1.)*0.05;
      /* poster olografico parete destra */
      if(pos.x>3.55 && abs(pos.z+0.35)<0.55 && abs(pos.y-1.8)<0.62){
        vec2 puv = vec2((pos.z+0.35)/0.5, (pos.y-1.8)/0.55);
        float frame = step(abs(puv.x),1.0)*step(abs(puv.y),1.0);
        float brd = frame - step(abs(puv.x),0.92)*step(abs(puv.y),0.94);
        float fig = length((puv-vec2(0.,0.25))*vec2(1.6,1.0))-0.28;
        fig = min(fig, length(vec2(puv.x*1.8, max(abs(puv.y+0.3)-0.35,0.)))-0.30);
        float scan = 0.6+0.4*sin(puv.y*40.0-t*6.0);
        emis += vec3(0.5,0.25,1.0)*brd*1.2;
        emis += vec3(0.2,0.7,1.0)*smoothstep(0.06,-0.06,fig)*frame*scan*0.9;
      }
      /* strisce luminose parete sinistra */
      if(pos.x<-3.55){
        float ls = smoothstep(0.025,0.0,abs(pos.y-1.55)) + smoothstep(0.025,0.0,abs(pos.y-2.15));
        emis += vec3(0.5,0.2,1.0)*ls*0.8*step(abs(pos.z+0.8),1.6);
      }
    }
  }
  else if(mid==4.0){ alb=vec3(0.14,0.14,0.16); gloss=0.85; }     /* piano scrivania */
  else if(mid==5.0){ alb=vec3(0.09,0.09,0.11); gloss=0.2; }      /* metallo */
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
  else if(mid==15.0){ alb=vec3(0.30,0.28,0.30); gloss=0.05; }    /* tessuto letto chiaro */
  else if(mid==17.0){ /* tazza */
    alb=vec3(0.06,0.06,0.08); gloss=0.4;
    vec3 mp = pos-vec3(1.18,0.85,0.60);
    emis += vec3(0.6,0.3,1.0)*smoothstep(0.012,0.0,abs(mp.y-0.055))*0.9;   /* bordo caldo */
    float logo = smoothstep(0.03,0.02,length(vec2(atan(mp.x,mp.z)*0.045, mp.y+0.01)));
    emis += vec3(0.3,0.7,1.0)*logo*0.6;
  }

  /* ----- illuminazione ----- */
  float ao = calcAO(pos,n);
  vec3 col = vec3(0.0);

  /* luce dalla finestra (città, cielo diurno freddo) */
  vec3 Lw = normalize(vec3(0.12,0.35,-1.0));
  float sh = softShadow(pos+n*0.02, Lw);
  col += alb * max(dot(n,Lw),0.0) * sh * vec3(0.75,0.85,1.05) * 2.4;

  /* ambiente */
  col += alb * (0.45+0.35*n.y) * vec3(0.30,0.30,0.42) * ao;
  col += alb * max(-n.z,0.0) * vec3(0.30,0.32,0.50) * ao;       /* bagliore città */

  /* luci puntiformi: neon + accenti caldi */
  {
    vec3 lps[6];
    vec3 lcs[6];
    lps[0]=vec3(-1.9,3.1,-0.5); lcs[0]=vec3(0.55,0.70,1.0)*2.4;
    lps[1]=vec3( 1.9,3.1,-0.5); lcs[1]=vec3(0.55,0.70,1.0)*2.4;
    lps[2]=vec3( 0.0,0.70,1.40); lcs[2]=vec3(0.6,0.3,1.0)*1.1;
    lps[3]=vec3(TAB_C.x,TAB_C.y+0.1,TAB_C.z+0.1); lcs[3]=vec3(0.45,0.40,1.0)*0.7;
    lps[4]=vec3(-1.55,1.00,0.55); lcs[4]=vec3(1.0,0.55,0.22)*0.9;   /* lampada calda scrivania */
    lps[5]=vec3( 3.3,1.55,-2.6);  lcs[5]=vec3(1.0,0.60,0.28)*1.3;   /* luce calda zona letto */
    for(int i=0;i<6;i++){
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
    float streak = smoothstep(0.35,0.0,abs(wuv.x-wuv.y*0.6+0.3))*0.05
                 + smoothstep(0.25,0.0,abs(wuv.x-wuv.y*0.6-0.55))*0.03;
    col += vec3(0.5,0.4,1.0)*streak;
    col *= 1.0-0.10*length(wuv*wuv);
  } else {
    vec3 pos = ro+rd*hit.x;
    col = shade(pos,rd,hit.y);
    col = mix(col, vec3(0.10,0.11,0.16), 1.0-exp(-hit.x*0.035));
  }

  fragColor = vec4(col,1.0);
}
