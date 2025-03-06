/* UNFINISHED
module game::assets::mat;

// region modules
import std::io, std::string;
import std::core::mem; // for malloc
import std::collections::list;
import game::main;
import engine::input;
import raylib5::rl;
import game::serialize::svs; // save system
// end_region

// region defines
def MaterialMapQueue  = List(<rl::MaterialMap>);
// end_region

// region constants
//const DEFAULT_SHOW_TIME = 3000; // ms
const DEFAULT_MATERIAL_MAP_COUNT = 5;
// end_region

enum GlobalParms : int (String keyword) {
    //General Keywords
    ALPHAZEROCLAMP = "alphazeroclamp",
    BACKSIDED      = "backsided",
    CLAMP          = "clamp",
    DECALINFO      = "decalInfo",
    DEFORM         = "deform",
    DESCRIPTION    = "description",
    DIFFUSE_MAP    = "diffusemap",
    specularmap    = "specularmap",
    NORMALMAP      = "normalmap",
    BUMPMAP        = "bumpmap",
    AOMAP          = "aomap",
    FORCEOPAQUE    = "forceOpaque",
    FORCEOVERLAYS  = "forceOverlays",
    FORCESHADOWS   = "forceShadows",
    GUISURF        = "guisurf",
    MIRROR         = "mirror",
    NOFOG          = "noFog",
    NOOVERLAYS     = "noOverlays",
    NOSELFSHADOW   = "noSelfShadow",
    NOSHADOWS      = "noShadows",
    POLYGONOFFSET  = "polygonOffset",
    EDITORIMAGE    = "editorimage",
    SORT           = "sort",
    SPECTRUM       = "spectrum", // for effects that only showup when lighted with a ligth of the same spectrum (invisible paint)
    TRANSLUCENT    = "translucent",
    TWOSIDED       = "twoSided",
    UNSMOOTHEDTANGENTS = "unsmoothedTangents",
    ZEROCLAMP      = "zeroclamp",
    // Light Keywords
    AMBIENTLIGHT  = "ambientLight",
    BLENDLIGHT    = "blendLight",
    FOGLIGHT      = "fogLight",
    LIGHTFALLOFFIMAGE = "lightFalloffImage",
    NOPORTALFOG   = "noPortalFo",
}

enum SurfaceParms : int (String keyword) {
    AIOBSTACLE    = "aiobstacle",
    AISOLID       = "aisolid",
    AREAPORTAL    = "areaportal",
    BLOOD         = "blood",
    CARDBOARD     = "cardboard",
    COLLISION     = "collision",
    DISCRETE      = "discrete",
    FLASHLIGHT_TRIGGER = "flashlight_trigger",
    FLESH         = "flesh",
    GLASS         = "glass",
    IKCLIP        = "ikclip",
    LADDER        = "ladder",
    LIQUID        = "liquid",
    METAL         = "metal",
    MONSTERCLIP   = "monsterclip",
    MOVEABLECLIP  = "moveableclip",
    NODAMAGE      = "nodamage",
    NOFRAGMENT    = "noFragment",
    NOIMPACT      = "noimpact",
    NONSOLID      = "nonsolid",
    NOSTEPS       = "nosteps",
    NULLNORMAL    = "nullnormal",
    PLASTIC       = "plastic",
    PLAYERCLIP    = "playerclip",
    QER_NOCARVE   = "qer_nocarve",
    RICOCHET      = "ricochet",
    SLICK         = "slick",
    SOLID         = "solid",
    STONE         = "stone",
    TRIGGER       = "trigger",
    WATER         = "water",
    WOOD          = "wood",
    SURFACETYPE32 = "surfacetype32",
    SURFACETYPE33 = "surfacetype33",
    SURFACETYPE34 = "surfacetype34",
    SURFACETYPE35 = "surfacetype35",
    SURFACETYPE36 = "surfacetype36",
    SURFACETYPE37 = "surfacetype37"
}

// Stage specific keywords used in material shaders.
enum StageParms : int(String keyword) {
    //General Keywords
    ALPHATEST        = "alphaTest",
    IGNOREALPHATEST  = "ignoreAlphaTest",
    ALPHAZEROCLAMP   = "alphazeroclamp",
    BLEND            = "blend",
    RED              = "red",
    BLUE             = "blue",
    GREEN            = "green",
    ALPHA            = "alpha",
    COLOR            = "color",            // This keyword is a shorthand way of using the individual red, green, blue and alpha keywords
    RGB              = "rgb",             //  ex.: rgb 0.5  then all color channels are set to 0.5
    RGBA             = "rgba",            //  same as rgb but also modifies alpha
    CAMERACUBEMAP    = "cameraCubeMap",
    CENTERSCALE      = "centerScale",
    CLAMP            = "clamp",
        // The colored keyword is used to mark a material as having the ability to have multiple colors multiples all channels of the associated map, by the corresponding shader parameters gathered from the entity which this material shader is applied.
    COLORED          = "colored",
    CUBEMAP          = "cubeMap",
    FORCEHIGHQUALITY = "forceHighQuality",
    VERTEXSHADER     = "vertexShader",   // a custom vertex shader
    VERTEXPARM       = "vertexParm",     // a vector4 that can be used in the vertex shader
    FRAGMENTMAP      = "fragmentMap",    // a texture that can be used in the fragment shader
    FRAGMENTSHADER   = "fragmentshader", // a custom fragment/pixel shader
    HIGHQUALITY      = "highquality",
    //INVERSEVERTEXCOLOR = "inverseVertexColor",
    LINEAR           = "linear",
    MAP              = "map",
    MASKALPHA        = "maskAlpha",
    MASKBLUE         = "maskBlue",
    MASKCOLOR        = "maskColor",
    MASKDEPTH        = "maskDepth",
    MASKGREEN        = "maskGreen",
    MASKRED          = "maskRed",
    MEGATEXTURE      = "megaTexture",
    MIRRORRENDERMAP  = "mirrorRenderMap",
    NEAREST          = "nearest",
    NOCLAMP          = "noclamp",
    NOPICMIP         = "nopicmip",
    REMOTERENDERMAP = "remoteRenderMap",
    ROTATE = "rotate",
    SCALE = "scale",
    SCROLL = "scroll",
    SHEAR = "shear",
    SOUNDMAP = "soundmap",
    TEXGEN = "texGen",
    TRANSLATE = "translate",
    UNCOMPRESSED = "uncompressed", //(alias for highquality)
    VERTEXCOLOR = "vertexColor",
    VIDEOMAP = "videomap",
    ZEROCLAMP = "zeroclamp"
}

// The order is important is how they are saved in the list queue a load time.
enum MatMapKind : int {
    ALBEDO,  //DIFFUSE
    NORMAL,
    SPECULAR,
    EMISSION,
    CUBEMAP
}

// Model model = LoadModel("resources/models/obj/castle.obj");                 // Load model
// Texture2D texture = LoadTexture("resources/models/obj/castle_diffuse.png"); // Load model texture
// model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = texture;            // Set map diffuse texture

struct Material {
    String name;
    String comment;
    MaterialMapQueue maps;
}

/*
struct IntroAnimation (SaveSystemInterface) {
   FrameQueue frames;
   Frame* current_frame;

   int fade_in_time;
   int fade_out_time;

   bool should_play;
}

fn void IntroAnimation.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void IntroAnimation.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn void initIntroAnimation(IntroAnimation* anim) {
    Frame* frame1 = mem::new(Frame);
    frame1.image  = gui::makePanelImage(
    main::asstManager.getTexture("logo_hm.png"),
    {0, 0, main::gpGame.screen.w, main::gpGame.screen.h}, 
    rl::WHITE);
    frame1.draw_time = DEFAULT_SHOW_TIME;
    //
    anim.frames.push(frame1);
    anim.current_frame = frame1;
    //
    input::makeKeyboardAction("noIntro", rl::KEY_ESCAPE);
}

fn void deinitIntroAnimation(IntroAnimation* anim) {
    foreach(frame : anim.frames) {
        if(frame) {
            gui::releasePanelImage(frame.image);
            frame.image = null;
            mem::free(frame);
        }
    }
    
    input::removeAction("noIntro");
}

fn void triggerIntroAnimation(IntroAnimation* anim) {
    anim.should_play = true;
}

fn bool updateIntroAnimation(IntroAnimation* anim) {
    if(anim.should_play == false) return false;
    
    int index = 0;
    
    do {
        bool stop_anim = input::getAction("noIntro").fnBecameTriggered();
        
        int current_time = main::gpGame.time_ms;
        if (!stop_anim && anim.current_frame && index == 0) // first frame
        {
            anim.current_frame.start_time = current_time;
            anim.current_frame.end_time   = anim.current_frame.start_time + anim.current_frame.draw_time;
            continue;
        }

        if(!stop_anim && anim.current_frame && anim.current_frame.end_time > 0 && 
           current_time <= anim.current_frame.end_time)
        {
            any panel = any_make(anim.current_frame.image, gui::Panel_Image.typeid);
            gui::updatePanel(panel);
            return true;
        }
        else if(stop_anim) {
            if(anim.current_frame && anim.frames.len() > 1 && index < anim.frames.len()) {
                anim.current_frame = anim.frames[index += 1];
                anim.current_frame.start_time = main::gpGame.time_ms;
                anim.current_frame.end_time   = anim.current_frame.start_time + anim.current_frame.draw_time;
            } else {
                anim.current_frame = null;
            }
        }
    } while(anim.current_frame != null);
    
    // todo don't skip the entire intro?
    deinitIntroAnimation(anim);
    
    return false;
}

fn void drawIntroAnimation(IntroAnimation* anim) {
    if(anim == null) return;
    
    if(anim.current_frame) {
        any panel = any_make(anim.current_frame.image, gui::Panel_Image.typeid);
        gui::drawPanel(panel);
    }
}


/*

fn void start_button_onOver(Widget* button) {
    //main::lgr::info(Where.CONSOLE, "Main Menu: I'm Over button: %s", button.name);
    ((WidgetButton*)button).color = ((WidgetButton*)button).over_color;
}

fn void start_button_onStopOver(Widget* button) {
    main::lgr::info(Where.CONSOLE, "Main Menu: Got out off button: %s", button.name);
}

fn void start_button_onRelease(Widget* button) {
    main::lgr::info(Where.CONSOLE, "Main Menu: Released button: %s", button.name);
}

fn void start_button_onPress(Widget* button) {
    //main::lgr::info(Where.CONSOLE, "Main Menu: I'm pressing button: %s", button.name);
    ((WidgetButton*)button).color = ((WidgetButton*)button).pressed_color;
}

fn void start_button_onSinglePress(Widget* button) {
    WidgetButton* btn = ((WidgetButton*)button);
    main::lgr::info(Where.CONSOLE, "Main Menu: I pressed button: %s once.", btn.name);
    if(/*!btn.sound_played && */rl::isSoundValid(*btn.interaction_sound)) {
        rl::playSound(*btn.interaction_sound);
        //btn.sound_played = true;
    }
}


