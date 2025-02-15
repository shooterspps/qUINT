/*=============================================================================

	ReShade 4 effect file
    github.com/martymcmodding

	Support me:
   		paypal.me/mcflypg
   		patreon.com/mcflypg

    Dither / Deband filter

    * Unauthorized copying of this file, via any medium is strictly prohibited
 	* Proprietary and confidential

=============================================================================*/
// Translation of the UI into Chinese by Lilidream.

/*=============================================================================
	Preprocessor settings
=============================================================================*/

/*=============================================================================
	UI Uniforms
=============================================================================*/

uniform float SEARCH_RADIUS <
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "去色带搜索半径";
> = 0.5;

uniform int BIT_DEPTH <
	ui_type = "slider";
	ui_min = 4; ui_max = 10;
    ui_label = "被去色带的数据的比特深度";
> = 8;

uniform bool AUTOMATE_BIT_DEPTH <
    ui_label = "自动比特深度检测";
> = true;

uniform int DEBAND_MODE <
	ui_type = "radio";
    ui_label = "抖动模式";
	ui_items = "无\0抖动\0去色带\0";
> = 2;

uniform bool SKY_ONLY <
    ui_label = "仅应用于天空";
> = false;

/*=============================================================================
	Textures, Samplers, Globals
=============================================================================*/

#define RESHADE_QUINT_COMMON_VERSION_REQUIRE 202
#include "qUINT_common.fxh"

/*=============================================================================
	Vertex Shader
=============================================================================*/

struct VSOUT
{
	float4                  vpos        : SV_Position;
    float2                  uv          : TEXCOORD0;
};

VSOUT VSMain(in uint id : SV_VertexID)
{
    VSOUT o;
    PostProcessVS(id, o.vpos, o.uv); //use original fullscreen triangle VS
    return o;
}

/*=============================================================================
	Functions
=============================================================================*/

/*=============================================================================
	Pixel Shaders
=============================================================================*/

void PSMain(in VSOUT i, out float3 o : SV_Target0)
{
	o = tex2D(qUINT::sBackBufferTex, i.uv).rgb;  

	const float2 magicdot = float2(0.75487766624669276, 0.569840290998);
    const float3 magicadd = float3(0, 0.025, 0.0125) * dot(magicdot, 1);
    float3 dither = frac(dot(i.vpos.xy, magicdot) + magicadd);

    if(SKY_ONLY)
    {
    	if(qUINT::linear_depth(i.uv) < 0.98) return;
    }

    float bit_depth = AUTOMATE_BIT_DEPTH ? BUFFER_COLOR_BIT_DEPTH : BIT_DEPTH;
    float lsb = rcp(exp2(bit_depth) - 1.0);

    if(DEBAND_MODE == 2)
    {
     	float2 shift;
     	sincos(6.283 * 30.694 * dither.x, shift.x, shift.y);
     	shift = shift * sqrt(dither.y);

     	float3 scatter = tex2Dlod(qUINT::sBackBufferTex, float4(i.uv + shift * 0.025 * SEARCH_RADIUS, 0, 0)).rgb;
     	float4 diff; 
     	diff.rgb = abs(o.rgb - scatter);
     	diff.w = max(max(diff.x, diff.y), diff.z);

     	o = lerp(o, scatter, diff.w <= lsb);
    }
    else if(DEBAND_MODE == 1)
    {
    	o += (dither - 0.5) * lsb;
    }
}

/*=============================================================================
	Techniques
=============================================================================*/

technique Debanding
< ui_tooltip = "                     >> qUINT::去色带(Debanding) <<\n\n"
			   "这是一个简单的去色带滤波器，旨在隐藏游戏中的颜色量化伪影。\n"
               "\nqUINT Debanding is written by Marty McFly / Pascal Gilcher"; ui_label="qUINT-光线追踪去色带(Deband)";>
{
    pass
	{
		VertexShader = VSMain;
		PixelShader  = PSMain;
	}
}