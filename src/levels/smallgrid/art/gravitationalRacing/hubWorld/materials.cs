singleton Material(gr_level_select_green)
{
   mapTo = "green";
   colorMap[0] = "textures/gravitationalRacing/hubWorld/greenEmissive.png";
   translucentBlendOp = "None";
   emissive[0] = "1";
};

singleton Material(gr_barrier_hubWorld)
{
   mapTo = "barrier_hubWorld";
   colorMap[0] = "textures/gravitationalRacing/hubWorld/barrier_hubWorld.png";
   emissive[0] = "1";
   useAnisotropic[0] = "1";
   scrollDir[0] = "0.103 0";
   scrollSpeed[0] = "0.100000001";
   diffuseColor[0] = "0.988235354 0.988235354 0.988235354 0.5";
   translucent = "1";
};

singleton Material(gr_greenEmissive)
{
   mapTo = "greenEmissive";
   colorMap[0] = "textures/gravitationalRacing/hubWorld/greenEmissive.png";
   emissive[0] = "1";
};

singleton Material(gr_whiteEmissive)
{
   mapTo = "whiteEmissive";
   colorMap[0] = "textures/gravitationalRacing/signs/sign_white.png";
   emissive[0] = "1";
};

singleton Material(gr_redEmissive)
{
   mapTo = "redEmissive";
   colorMap[0] = "textures/gravitationalRacing/hubWorld/redEmissive.png";
   emissive[0] = "1";
};

singleton Material(gr_blueEmissive)
{
   mapTo = "blueEmissive";
   colorMap[0] = "textures/gravitationalRacing/hubWorld/blueEmissive.png";
   emissive[0] = "1";
};

singleton material(gr_level_select_light_blue)
{
   mapTo = "light_blue";
   colorMap[0] = "textures/gravitationalRacing/hubWorld/level_select/light_blue";
   translucentBlendOp = "None";
};

singleton material(gr_level_select_portal)
{
   mapTo = "portal";
   colorMap[0] = "textures/gravitationalRacing/hubWorld/level_select/portal";
   translucentBlendOp = "None";
   animFlags[0] = "0x00000001";
   scrollDir[0] = "0.0689999983 0";
   scrollSpeed[0] = "0.588";
   emissive[0] = "0";
   rotSpeed[0] = "0.118000001";
   diffuseColor[0] = "0.749019623 0.749019623 0.749019623 0.00800000038";
   glow[0] = "1";
};

singleton material(gr_level_select_dark_blue)
{
   mapTo = "dark_blue";
   colorMap[0] = "textures/gravitationalRacing/hubWorld/level_select/dark_blue";
   translucentBlendOp = "None";
};

singleton Material(gr_yellowEmissive)
{
   mapTo = "yellowEmissive";
   colorMap[0] = "textures/gravitationalRacing/hubWorld/yellowEmissive.png";
   emissive[0] = "1";
};
