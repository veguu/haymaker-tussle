import os, sys, math, random, json
from pathlib import Path
import bpy, bmesh, numpy as np
from mathutils import Vector
ROOT=str(Path(__file__).resolve().parents[2])
sys.path.insert(0,ROOT+'/design/maps')
sys.path.insert(0,os.environ.get('LIHFOLK_MODEL_HELPERS',str(Path(ROOT).parents[2]/'skills/roblox-blender-modeling/scripts')))
os.environ['HT_MAP']='gnomon'
import common as C, paint as P, lihfolk_bpy as LF
OUT=ROOT+'/design/maps/out/gnomon/lush'
UP=ROOT+'/design/maps/out/gnomon/upload'
os.makedirs(OUT,exist_ok=True)
os.makedirs(UP,exist_ok=True)
base=OUT+'/gnomon_lush.blend'
if not os.path.exists(base):base=ROOT+'/design/maps/out/gnomon/grass-revision/gnomon.blend'
bpy.ops.wm.open_mainfile(filepath=base)
for o in list(bpy.data.objects):
    if o.name.startswith(('MeadowTuft_','LushGrass_','Obstacles_')): bpy.data.objects.remove(o,do_unlink=True)

def material(name,low,high,leaf=False):
    n=256; v,u=np.mgrid[0:n,0:n]/(n-1)
    t=(v*.7+.15+.09*np.sin(u*15+v*9)+.045*np.sin(u*47-v*13)) if leaf else (.48+.20*np.sin(u*12+v*4)*np.sin(v*16-u*3)+.06*np.sin(u*38+v*29))
    if leaf:t+=.12*np.exp(-((u-.5)/.09)**2)
    rgb=np.array(low)[None,None,:]+np.clip(t,0,1)[...,None]*(np.array(high)-low)[None,None,:]
    im=bpy.data.images.new(name, width=n,height=n)
    pixels=np.concatenate((rgb/255,np.ones((n,n,1))),axis=2).astype(np.float32)
    im.pixels.foreach_set(pixels.ravel());im.filepath_raw=OUT+'/'+name+'.png';im.file_format='PNG';im.save();im.pack()
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.94
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    return m

turf=material('LushTurf',(79,163,55),(139,207,72))
leaf=material('LushBlade',(63,150,51),(172,225,94),True)
soil=material('LushEarth',(103,76,65),(166,127,87))
stone=material('LushRock',(81,77,92),(128,111,96))
rim=material('LushEdge',(48,130,67),(112,190,67))
changed=[]
for o in list(bpy.data.objects):
    if o.type!='MESH':continue
    mat=None
    if o.name.startswith(('Meadow_','Rim_Turf')) or o.name.endswith('_Cap'):mat=turf
    elif o.name.startswith('Lip_Turf'):mat=rim
    elif o.name.startswith(('Strata_Cream','Strata_Sand')):mat=soil
    elif o.name.startswith('Strata_Bluegrey'):mat=stone
    if mat:
        o.data.materials.clear();o.data.materials.append(mat)
        if not o.data.uv_layers:
            o.data.uv_layers.new(name='UVMap')
            for p in o.data.polygons:
                for li in p.loop_indices:
                    co=o.data.vertices[o.data.loops[li].vertex_index].co
                    o.data.uv_layers.active.data[li].uv=((co.x%20)/20,(co.y%20)/20)
        changed.append(o)

# Each tuft is three broad, tapered, low leaves. Solid triangular cross sections,
# anchored root below the floor. No visibility toggles, growth or per-frame chunk movement.
rng=random.Random(82713);chunks={};tufts=0
def blade(bm,uv,base,angle,length,width,height):
    d=Vector((math.cos(angle),math.sin(angle),0));side=Vector((-d.y,d.x,0))
    stations=[(0,.10,-.035),(.46,1,height)]
    rings=[];coords={}
    for j,(t,w,z) in enumerate(stations):
        center=base+d*(t*length)+Vector((0,0,z))
        ring=[bm.verts.new(center+side*(width*w)),bm.verts.new(center+Vector((0,0,.13*w))),bm.verts.new(center-side*(width*w))]
        rings.append(ring)
        for k,vert in enumerate(ring):coords[vert]=([.04,.5,.96][k],.02+t*.95)
    tip=bm.verts.new(base+d*length+Vector((0,0,height*.72)));coords[tip]=(.5,.98)
    faces=[rings[0][::-1]]
    for j in range(1):
        for k in range(3):faces.append([rings[j][k],rings[j][(k+1)%3],rings[j+1][(k+1)%3],rings[j+1][k]])
    for k in range(3):faces.append([rings[1][k],rings[1][(k+1)%3],tip])
    for vs in faces:
        f=bm.faces.new(vs)
        for loop in f.loops:loop[uv].uv=coords[loop.vert]

for iy,y in enumerate(np.arange(-172,173,4.0)):
    for ix,x in enumerate(np.arange(-209,210,4.0)):
        x+=rng.uniform(-1.1,1.1);y0=y+rng.uniform(-1.1,1.1)
        if (x/209)**2+(y0/172)**2>1:continue
        key=(int((x+213)//40),int((y0+176)//40))
        if key not in chunks:
            bm=bmesh.new();chunks[key]=(bm,bm.loops.layers.uv.new('UVMap'))
        bm,uv=chunks[key];turn=rng.uniform(0,math.tau)
        for j in range(3):blade(bm,uv,Vector((x,y0,0)),turn+j*2.1+rng.uniform(-.6,.6),rng.uniform(2.15,3.55),rng.uniform(.36,.68),rng.uniform(.25,.62))
        tufts+=1
grass=[];gates={}
for i,(key,(bm,uv)) in enumerate(sorted(chunks.items())):
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    o=C.mesh_object('LushGrass_%03d'%i,bm,leaf,smooth=True)
    grass.append(o)
    passed,fails,report=LF.gate(o,cls='hero',surface_checks=(i==len(chunks)//2))
    gates[o.name]={'passed':passed,'fails':fails,'triangles':report['tris']}
    assert passed,(o.name,fails)
print('GRASS',tufts,'tufts',len(grass),'meshes',sum(v['triangles'] for v in gates.values()),'triangles',flush=True)

manifest={'tufts':tufts,'height':.75,'groups':{},'gate':gates}
for name,objs in [('lush_surfaces',changed),('lush_grass_a',grass[::2]),('lush_grass_b',grass[1::2])]:
    records={}
    for o in objs:
        bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
        bounds=[o.matrix_world@Vector(c) for c in o.bound_box]
        lo=[min(p[k] for p in bounds) for k in range(3)];hi=[max(p[k] for p in bounds) for k in range(3)]
        mid=[(lo[k]+hi[k])/2 for k in range(3)]
        records[o.name]={'center':[mid[0],mid[2],-mid[1]],'size':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'triangles':len(o.data.polygons)}
    for o in bpy.context.view_layer.objects:o.select_set(o in objs)
    path=UP+'/'+name+'.glb'
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_normals=True,export_materials='EXPORT')
    assert os.path.getsize(path)<20_000_000
    manifest['groups'][name]={'file':path,'bytes':os.path.getsize(path),'meshes':records}
with open(OUT+'/manifest.json','w') as f:json.dump(manifest,f,indent=2)
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/gnomon_lush.blend')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=1100;scene.render.resolution_y=750;scene.render.resolution_percentage=100
scene.camera=C.camera('LushReview',(28,-38,30),(0,0,0),40)
scene.render.filepath=OUT+'/close.png';bpy.ops.render.render(write_still=True)
scene.camera=C.camera('LushOverview',(350,-450,330),(0,0,-25),40)
scene.render.filepath=OUT+'/overview.png';bpy.ops.render.render(write_still=True)
print('DONE',flush=True)
