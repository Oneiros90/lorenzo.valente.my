#version 300 es
precision highp float;
out vec4 fragColor;
uniform sampler2D uScene;
uniform sampler2D uBloom;
uniform vec2  iResolution;
uniform float iTime;
uniform float uFade;

float hash21(vec2 p){ p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y); }
vec2 hash22(vec2 p){ float n=hash21(p); return vec2(n,hash21(p+n)); }
vec3 aces(vec3 x){ return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14),0.,1.); }

void main(){
  vec2 uv = gl_FragCoord.xy/iResolution;
  float t = iTime;

  /* scena (CA a 1 sample — risparmio bandwidth post) */
  vec2 c = uv-0.5;
  vec3 col = texture(uScene, uv).rgb;

  /* bloom */
  vec3 bloom = texture(uBloom, uv).rgb;
  col += bloom*0.95;

  /* pulviscolo fluttuante */
  for(int i=0;i<3;i++){
    float fi=float(i);
    vec2 p = uv*vec2(iResolution.x/iResolution.y,1.0)*(4.0+fi*3.0);
    p.y -= t*(0.015+fi*0.012);
    p.x += sin(t*0.3+fi*2.0)*0.05;
    vec2 id=floor(p), f=fract(p)-0.5;
    vec2 o=hash22(id+fi*17.0)-0.5;
    float d=length(f-o*0.8);
    float vis=step(0.82,hash21(id+fi*31.0));
    col += vec3(0.42,0.48,0.85)*smoothstep(0.025,0.0,d)*vis*(0.03+0.03*sin(t*1.5+hash21(id)*20.0));
  }

  /* tonemap ACES: notturno ma con i materiali ancora leggibili */
  col = aces(col*1.18);

  /* grade: ombre navy, mai nero puro */
  col = pow(col, vec3(1.05,1.04,1.00));
  col += vec3(0.008,0.010,0.018)*(1.0-col);

  /* scanline + flicker */
  col *= 0.97+0.03*sin(gl_FragCoord.y*1.7);
  col *= 0.99+0.01*sin(t*60.0);

  /* vignettatura */
  float vig = 1.0-0.52*dot(c*1.25,c*1.25);
  col *= clamp(vig,0.,1.);

  /* grana */
  col += (hash21(uv*vec2(1920.,1080.)+fract(t)*37.0)-0.5)*0.028;

  col *= uFade;
  fragColor = vec4(col,1.0);
}
