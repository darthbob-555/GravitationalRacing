singleton Material(gr_changeable_colour)
{
   mapTo = "gr_changeable_colour";
   detailScale[0] = "1010 2";
   useAnisotropic[0] = "1";
   specularPower[0] = "1";
   specularStrength[0] = "5";
   pixelSpecular[0] = "0";
   glow[0] = "0";
   emissive[0] = "1";
   diffuseColor[0] = "1 1 1 2";
   diffuseColor[1] = "White";
   instanceDiffuse[0] = "1";
   castShadows = "0";	
   specularStrength0 = "5";
   materialTag0 = "Miscellaneous";
};

singleton Material(compass_Color_M00)
{
   mapTo = "Color_M00";
   translucentBlendOp = "None";
   colorMap[0] = "textures/gravitationalRacing/signs/sign_white.png";
   emissive[0] = "1";
};

singleton Material(compass_Color_M09)
{
   mapTo = "Color_M09";
   diffuseColor[0] = "black";
   translucentBlendOp = "None";
};
