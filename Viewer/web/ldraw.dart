library LDRAW;

import 'dart:collection';
import 'dart:html';
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import 'webgl.dart';

class LDrawContext{
  Matrix4 offset;
  double r, g, b; //Main color
  double er, eg, eb; //Secondary color
  
  LDrawContext( Matrix4 offset, double r, double g, double b ){
    this.offset = offset.clone();
    this.r = r;
    this.g = g;
    this.b = b;
    er = 0x33/255;
    eb = 0x33/255;
    eg = 0x33/255;
    //TODO: does Dart have some smart syntax for this?
  }
  
  LDrawContext update_color( int code ){
    LDrawContext sub = new LDrawContext( offset, r,g,b );
    switch( code ){
      case 16: break; //Do nothing, use main color
      case 24: break; //TODO: !
      case 4: sub.r=0xC9/255; sub.g=0x1A/255; sub.b=0x09/255; break; 
      case 0: sub.r=0x00/255; sub.g=0x00/255; sub.b=0x00/255; break; 
      case 7: sub.r=0x9B/255; sub.g=0xA1/255; sub.b=0x9D/255; break; 
    }
    return sub;
  }
}

class LDrawFileContent extends LDrawPrimitive{
  List<LDrawPrimitive> primitives = new List<LDrawPrimitive>();

  void draw( Canvas canvas, LDrawContext context ){
    primitives.forEach( (x) => x.draw( canvas, context ) );
  }
  void init(String content){
    try{
    List<String> lines = content.split("\n");
    lines.removeWhere((test)=>test.isEmpty);
    lines.forEach((line){
      List<String> parts = line.trim().split(" ");
      parts.removeWhere((test)=>test.isEmpty); //Note: could mess up file names if they contain spaces 
      
      if( parts.length > 0 )
         switch( parts.removeAt(0) ){
           case '0': parse_comment(parts); break;
           case '1': parse_subfile(parts); break;
           case '2': parse_line(parts); break;
           case '3': parse_triangle(parts); break;
           case '4': parse_quad(parts); break;
           case '5': parse_optional(parts); break;
         }
    });
    }
    catch(object){
      print(object);
    }
  }
  
  Float32List from_string_list( List<String> parts, int start, int amount ){
    Float32List list = new Float32List( amount );
    for( int i=0; i<amount; i++ ){
      list[i]=( double.parse( parts[i+start] ) );
    }
    return list;
  }
  
  void parse_comment(List<String> parts){
    if( parts.length > 0 )
      switch( parts[0] ){
        case "STEP": print("step"); break;
        case "ROTATION": print("rotation"); break;
        //default: print("comment");
      }
  }
  
  void parse_subfile(List<String> parts){
    assert(parts.length >= 14);
    
    LDrawFile sub = new LDrawFile();
    sub.color = int.parse( parts[0] );
    double x = double.parse( parts[1] );
    double y = double.parse( parts[2] );
    double z = double.parse( parts[3] );
    double a = double.parse( parts[4] );
    double b = double.parse( parts[5] );
    double c = double.parse( parts[6] );
    double d = double.parse( parts[7] );
    double e = double.parse( parts[8] );
    double f = double.parse( parts[9] );
    double g = double.parse( parts[10] );
    double h = double.parse( parts[11] );
    double i = double.parse( parts[12] );
    sub.pos = new Matrix4( a, d, g, 0.0, b, e, h, 0.0, c, f, i, 0.0, x, y, z, 1.0 );
    
    String filepath = parts.sublist(13).join(" ").trim();
    load_ldraw( sub, filepath );
    primitives.add(sub);
  }
  void parse_line(List<String> parts){
    assert(parts.length >= 7);
    
    LDrawLine line = new LDrawLine();
    line.color = int.parse( parts[0] );
    line.vertices = from_string_list( parts, 1, 6 );
    
    for(int i=0; i<primitives.length; i++)
      if( primitives[i] is LDrawLine ){
        LDrawLine old_line = primitives[i];
        if( old_line.color == line.color ){
          old_line.vertices = combine( old_line.vertices, line.vertices );
          return;
        }
      }
    
    primitives.add(line);
  }
  void parse_triangle(List<String> parts){
    assert(parts.length >= 10);
    
    LDrawTriangle tri = new LDrawTriangle();
    tri.color = int.parse( parts[0] );
    tri.vertices = from_string_list( parts, 1, 9 );
    
    for(int i=0; i<primitives.length; i++)
      if( primitives[i] is LDrawTriangle ){
        LDrawTriangle old_tri = primitives[i];
        if( old_tri.color == tri.color ){
          old_tri.vertices = combine( old_tri.vertices, tri.vertices );
          return;
        }
      }

    primitives.add(tri);
  }
  void parse_quad(List<String> parts){
    assert(parts.length >= 13);
    
    LDrawTriangle quad = new LDrawTriangle();
    quad.color = int.parse( parts[0] );
    Float32List arr1 = from_string_list( parts, 1, 9 );
    Float32List arr2 = from_string_list( parts, 1+3, 9 );
    for(int i=0; i<3; i++)
      arr2[i] = arr1[i];
    quad.vertices = combine( arr1, arr2 );

    for(int i=0; i<primitives.length; i++)
      if( primitives[i] is LDrawTriangle ){
        LDrawTriangle old_tri = primitives[i];
        if( old_tri.color == quad.color ){
          old_tri.vertices = combine( old_tri.vertices, quad.vertices );
          return;
        }
      }
    
    primitives.add(quad);
  }
  void parse_optional(List<String> parts){
    assert(parts.length >= 13);
    LDrawOptional opt = new LDrawOptional();
    opt.color = int.parse( parts[0] );
    opt.x1 = double.parse( parts[1] );
    opt.y1 = double.parse( parts[2] );
    opt.z1 = double.parse( parts[3] );
    opt.x2 = double.parse( parts[4] );
    opt.y2 = double.parse( parts[5] );
    opt.z2 = double.parse( parts[6] );
    opt.x3 = double.parse( parts[7] );
    opt.y3 = double.parse( parts[8] );
    opt.z3 = double.parse( parts[9] );
    opt.x4 = double.parse( parts[10] );
    opt.y4 = double.parse( parts[11] );
    opt.z4 = double.parse( parts[12] );
    primitives.add(opt);
  }
}
Float32List combine(Float32List arr1, Float32List arr2){
  Float32List arr = new Float32List( arr1.length + arr2.length );
  for(int i=0; i<arr1.length; i++)
    arr[i] = arr1[i];
  for(int i=0; i<arr2.length; i++)
    arr[i+arr1.length] = arr2[i];
  return arr;
}

class LDrawFile extends LDrawPrimitive{
  int color = 16;
  Matrix4 pos = new Matrix4.identity();
  LDrawFileContent content;

  void draw( Canvas canvas, LDrawContext context ){
    Matrix4 new_pos = context.offset.clone().multiply(pos);
    canvas.move( new_pos );
    content.draw(canvas, new LDrawContext( new_pos, context.r, context.g, context.b ).update_color(color) );
    canvas.move( context.offset );
  }
}

class LDrawLine extends LDrawPrimitive{
  int color = 16;
  Float32List vertices;

  void draw( Canvas canvas, LDrawContext context ){
    LDrawContext con = context.update_color(color);
    canvas.setColor( con.er, con.eg, con.eb );
    canvas.draw_lines( vertices, vertices.length ~/ 3 );
  }
}

class LDrawTriangle extends LDrawPrimitive{
  int color = 16;
  Float32List vertices;

  void draw( Canvas canvas, LDrawContext context ){
    LDrawContext con = context.update_color(color);
    canvas.setColor( con.r, con.g, con.b );
    canvas.draw_triangles( vertices, vertices.length ~/ 3 );
  }
}

class LDrawQuad extends LDrawPrimitive{
  int color = 16;
  Float32List vertices;

  void draw( Canvas canvas, LDrawContext context ){
    LDrawContext con = context.update_color(color);
  //  canvas.move(context.offset);
    canvas.setColor( con.r, con.g, con.b );
    canvas.draw_triangle_fan( vertices, 4 );
  }
}

class LDrawOptional extends LDrawPrimitive{
  int color = 16;
  double x1 = 0.0, y1 = 0.0, z1 = 0.0;
  double x2 = 0.0, y2 = 0.0, z2 = 0.0;
  double x3 = 0.0, y3 = 0.0, z3 = 0.0;
  double x4 = 0.0, y4 = 0.0, z4 = 0.0;
  
}

abstract class LDrawPrimitive{
  void draw( Canvas canvas, LDrawContext context ){ }//TODO: make it abstract
}

void load_ldraw( LDrawFile file, String name ){
  if( cache[name] != null ){
    file.content = cache[name];
    return;
  }
  
  loading++;
  List<String> names = new List<String>();
  cache[name] = new LDrawFileContent();
  file.content = cache[name];
  //names.add( name );
  names.add( "ldraw/parts/" + name );
  names.add( "ldraw/p/" + name );
  //names.add( "ldraw/models/" + name );
  load_ldraw_list( names, name );
}

Map<String,LDrawFileContent> cache = new HashMap<String,LDrawFileContent>();
int loading = 0;

void load_ldraw_list( List<String> names, String name ){
  String try_load = names.removeAt(0);
  HttpRequest.getString( try_load )
  .then((content){
    cache[name].init(content);
    loading--;
  })
  .catchError((onError){
    if( names.length > 0 )
      load_ldraw_list( names, name );
    else{
      print( "Could not retrive file: " + name + " :\\" );
      loading--;
    }
  });
}