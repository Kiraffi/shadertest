use godot::prelude::*;

use godot::engine::*;
use bytemuck::*;
struct GdExtExt;
struct GdCamExtExt;

#[gdextension]
unsafe impl ExtensionLibrary for GdExtExt{}
unsafe impl ExtensionLibrary for GdCamExtExt{}

const BLADES: u32 = 128 * 128 * 16;
const VERTICES_PER_BLADE: u32 = 3;

#[derive(Copy, Clone, Pod, Zeroable)]
#[repr(C)]
struct VC2{
    x: f32,
    y: f32,
}

#[derive(Copy, Clone, Debug, Pod, Zeroable)]
#[repr(C)]
struct VC3{
    x: f32,
    y: f32,
    z: f32
}


#[derive(GodotClass)]
#[class(base=RenderSceneBuffersExtension)]
struct GdCamExt
{
    #[base]
    base: Base<RenderSceneBuffersExtension>,
}
#[godot_api]
impl IRenderSceneBuffersExtension for GdCamExt
{
    fn init(base: Base<RenderSceneBuffersExtension>) -> Self
    {
        GdCamExt {base}
    }

    fn configure(&mut self, config: Gd<RenderSceneBuffersConfiguration>)
    {
        godot_print!("configure");
    }
}

#[derive(GodotClass)]
#[class(base=MeshInstance3D)]
struct GdExt
{
    #[base]
    base: Base<MeshInstance3D>,
    rd: Gd<RenderingDevice>,

    shader: Rid,
    buffer0: Rid,
    buffer1: Rid,
    buffer2: Rid,
    buffer3: Rid,

    uniform0: Gd<RdUniform>,
    uniform1: Gd<RdUniform>,
    uniform2: Gd<RdUniform>,
    uniform3: Gd<RdUniform>,

    pipeline: Rid,
    compute_list: i64,
}

fn create_uniform(buffer: Rid, binding: i32) -> Gd<RdUniform>
{
    let mut uniform = RdUniform::new_gd();
    uniform.set_uniform_type(rendering_device::UniformType::STORAGE_BUFFER);
    uniform.set_binding(binding);
    uniform.add_id(buffer);
    return uniform;
}

#[godot_api]
impl IMeshInstance3D for GdExt
{
    fn init(base: Base<MeshInstance3D>) -> Self
    {
        godot_print!("Hello world!");

        let rs = RenderingServer::singleton();
        let mut rd = RenderingServer::create_local_rendering_device(&rs).unwrap();



        //let shader_file: Gd<RdShaderFile> = load("res://compute_rust.glsl");
        let shader_file: Gd<RdShaderFile> = load("res://compute.glsl");
        let shader_spirv: Gd<RdShaderSpirv> = shader_file.get_spirv().unwrap();
        let shader = rd.shader_create_from_spirv(shader_spirv);

        /*
        let arr: [f32; 10] = [1.0f32, 2.0f32, 3.0f32, 4.0f32, 5.0f32, 6.0f32, 7.0f32, 8.0f32, 9.0f32, 10.0f32];

        bytemuck::bytes_of(&arr);
        let input_bytes = PackedByteArray::from(bytemuck::bytes_of(&arr));

        let buffer0 = rd.storage_buffer_create(4 * 10);
        rd.buffer_update(buffer0, 0, 40, input_bytes);
*/

        // The temp update up.
        let buffer0 = rd.storage_buffer_create(BLADES * VERTICES_PER_BLADE * 3 * 4); // pos xyz
        let buffer1 = rd.storage_buffer_create(BLADES * VERTICES_PER_BLADE * 3 * 4); // nor xyz
        let buffer2 = rd.storage_buffer_create(BLADES * VERTICES_PER_BLADE * 1 * 4); // i32 index
        let buffer3 = rd.storage_buffer_create(BLADES * VERTICES_PER_BLADE * 2 * 4); // uv xy

        let mut uniforms : Array<Gd<RdUniform>> = Array::new();
        let uniform0 = create_uniform(buffer0, 0);
        let uniform1 = create_uniform(buffer1, 1);
        let uniform2 = create_uniform(buffer2, 2);
        let uniform3 = create_uniform(buffer3, 3);

        uniforms.push(uniform0.clone());
        uniforms.push(uniform1.clone());
        uniforms.push(uniform2.clone());
        uniforms.push(uniform3.clone());

        let uniform_set = rd.uniform_set_create(uniforms, shader, 0);


        let pipeline = rd.compute_pipeline_create(shader);
        let compute_list = rd.compute_list_begin();
        rd.compute_list_bind_compute_pipeline(compute_list, pipeline);
        rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
        rd.compute_list_dispatch(compute_list, BLADES / 128, 1, 1);
        rd.compute_list_end();

        GdExt { base, rd, shader, buffer0, buffer1, buffer2, buffer3,
            uniform0, uniform1, uniform2, uniform3, pipeline, compute_list }
    }
    fn process(&mut self, delta: f64)
    {
        /*
        //godot_print!("hello from process {}", delta);
        self.rd.submit();
        self.rd.sync();


        let mut surface_array = VariantArray::new();
        surface_array.resize(mesh::ArrayType::MAX.ord() as usize);


        let output_bytes0 = self.rd.buffer_get_data(self.buffer0);
        let output_bytes1 = self.rd.buffer_get_data(self.buffer1);
        let output_bytes2 = self.rd.buffer_get_data(self.buffer2);
        let output_bytes3 = self.rd.buffer_get_data(self.buffer3);


        let packed0 = bytemuck::cast_slice::<u8, VC3>(output_bytes0.as_slice());
        let packed0 = unsafe { std::mem::transmute::<&[VC3], &[Vector3]>(packed0) };
        let packed0 = PackedVector3Array::from(packed0);

        let packed1 = bytemuck::cast_slice::<u8, VC3>(output_bytes1.as_slice());
        let packed1 = unsafe { std::mem::transmute::<&[VC3], &[Vector3]>(packed1) };
        let packed1 = PackedVector3Array::from(packed1);

        let packed2 = bytemuck::cast_slice::<u8, i32>(output_bytes2.as_slice());
        let packed2 = PackedInt32Array::from(packed2);

        let packed3 = bytemuck::cast_slice::<u8, VC2>(output_bytes3.as_slice());
        let packed3 = unsafe { std::mem::transmute::<&[VC2], &[Vector2]>(packed3) };
        let packed3 = PackedVector2Array::from(packed3);

        surface_array.set(mesh::ArrayType::VERTEX.ord() as usize, packed0.to_variant());
        surface_array.set(mesh::ArrayType::NORMAL.ord() as usize, packed1.to_variant());
        surface_array.set(mesh::ArrayType::INDEX.ord() as usize, packed2.to_variant());
        surface_array.set(mesh::ArrayType::TEX_UV.ord() as usize, packed3.to_variant());


        //surface_array.set(mesh::ArrayType::VERTEX.ord() as usize, output_bytes0.to_variant());
        //surface_array.set(mesh::ArrayType::NORMAL.ord() as usize, output_bytes1.to_variant());
        //surface_array.set(mesh::ArrayType::INDEX.ord() as usize, output_bytes2.to_variant());
        //surface_array.set(mesh::ArrayType::TEX_UV.ord() as usize, output_bytes3.to_variant());

        let mut mesh = self.base().get_mesh().unwrap();
        let mut array_mesh = mesh.cast::<ArrayMesh>();
        array_mesh.clear_surfaces();
        array_mesh.add_surface_from_arrays(mesh::PrimitiveType::TRIANGLES, surface_array);

        //self.base_mut().set_mesh(self.mesh);

        //let packed5 = bytemuck::cast_slice::<u8, f32>(output_bytes0.as_slice());
        //godot_print!("output: {:?}", packed0);
*/

        /*
        let output_bytes = self.rd.buffer_get_data(self.buffer0);
        let output = bytemuck::cast_slice::<u8, f32>(output_bytes.as_slice());
        godot_print!("output: {:#?}", output);
        */
    }

}

