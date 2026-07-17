#version 300 es
precision highp float;
const vec2 P[3] = vec2[3](vec2(-1.,-1.),vec2(3.,-1.),vec2(-1.,3.));
void main(){ gl_Position = vec4(P[gl_VertexID],0.,1.); }
