singleton Material(gr_strip_red)
{
   mapTo = "strip_red";
   colorMap[0] = "textures/gravitationalRacing/track/strip_red.png";
   emissive[0] = "1";
};

singleton Material(gr_strip_orange)
{
   mapTo = "strip_orange";
   colorMap[0] = "textures/gravitationalRacing/track/strip_orange.png";
   emissive[0] = "1";
};

singleton Material(gr_strip_white)
{
   mapTo = "strip_white";
   colorMap[0] = "textures/gravitationalRacing/track/strip_white.png";
   emissive[0] = "1";
};

singleton Material(gr_strip_blue)
{
   mapTo = "strip_blue";
   colorMap[0] = "textures/gravitationalRacing/track/strip_blue.png";
   emissive[0] = "1";
};

singleton Material(gr_strip_green)
{
   mapTo = "strip_green";
   colorMap[0] = "ltextures/gravitationalRacing/track/strip_green.png";
   emissive[0] = "1";
};

singleton Material(gr_strip_yellow)
{
   mapTo = "strip_yellow";
   colorMap[0] = "textures/gravitationalRacing/track/strip_yellow.png";
   emissive[0] = "1";
   materialTag0 = "Miscellaneous";
};

singleton Material(gr_wall_arrow_right)
{
   mapTo = "wall_arrow_right";
   colorMap[0] = "textures/gravitationalRacing/track/wall_arrow_right.png";
   useAnisotropic[0] = "1";
   emissive[0] = "0";
   animFlags[0] = "0x00000001";
   scrollDir[0] = "-1 0";
   scrollSpeed[0] = "0.5";
   materialTag0 = "Miscellaneous";
   glow[0] = "1";
};

singleton Material(gr_wall_arrow_left)
{
   mapTo = "wall_arrow_left";
   colorMap[0] = "textures/gravitationalRacing/track/wall_arrow_left.png";
   emissive[0] = "0";
   animFlags[0] = "0x00000001";
   scrollDir[0] = "1 0";
   scrollSpeed[0] = "0.5";
   materialTag0 = "Miscellaneous";
   glow[0] = "1";
   useAnisotropic[0] = "1";
};

singleton Material(gr_checkered_flag)
{
   mapTo = "checkered_flag";
   colorMap[0] = "textures/gravitationalRacing/checkpoints/checkered_flag.png";
   glow[0] = "1";
   emissive[0] = "1";
};

