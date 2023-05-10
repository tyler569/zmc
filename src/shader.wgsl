struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) position: vec3<f32>,
    @location(1) color: vec3<f32>,
}

@vertex
fn vs_main(@builtin(vertex_index) index: u32) -> VertexOutput {
    var out: VertexOutput;

    let x = f32(i32(index) - 1) * 0.5;
    let y = f32(i32(index & 1u) * 2 - 1) * 0.5;

    out.clip_position = vec4<f32>(x, y, 0.0, 1.0);
    out.position = out.clip_position.xyz;

    if (index == 0u) {
        out.color = vec3<f32>(1.0, 0.0, 0.0);
    } else if (index == 1u) {
        out.color = vec3<f32>(0.0, 1.0, 0.0);
    } else if (index == 2u) {
        out.color = vec3<f32>(0.0, 0.0, 1.0);
    }

    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    // return vec4<f32>(0.88, 0.11, 0.31, 1.0);

    return vec4<f32>(in.color, 1.0);
}
