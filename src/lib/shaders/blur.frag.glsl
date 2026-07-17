#version 300 es
precision highp float;
out vec4 fragColor;
uniform sampler2D uTex;
uniform vec2 uDir;        // (1,0) o (0,1) in texel
uniform float uThreshold; // >0 solo al primo passo
void main(){
  vec2 res = vec2(textureSize(uTex,0));
  vec2 uv = gl_FragCoord.xy/res*vec2(res)/res; // uv in [0,1]
  uv = gl_FragCoord.xy / vec2(textureSize(uTex,0));
  float w[5];
  w[0]=0.227027; w[1]=0.194594; w[2]=0.121621; w[3]=0.054054; w[4]=0.016216;
  vec3 acc = vec3(0.0);
  for(int i=-4;i<=4;i++){
    vec2 o = uDir*float(i)/res*2.0;
    vec3 s = texture(uTex, uv+o).rgb;
    if(uThreshold>0.0) s = max(s-uThreshold, vec3(0.0));
    acc += s * w[i<0?-i:i];
  }
  fragColor = vec4(acc,1.0);
}
