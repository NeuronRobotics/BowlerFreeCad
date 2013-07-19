use <../Tolerance.scad>

function BallBearingDiam() = 22 + 3dPrinterTolerance(); //USUALLY 22
function BallBearingHeight() = 7 + 3dPrinterTolerance(); //USUALLY 7
function BallBearingInnerDiam()= 7.9 - 3dPrinterTolerance(); //USUALLY 7.9

module BallBearing()
{
cylinder(BallBearingHeight(), BallBearingDiam()/2, BallBearingDiam()/2);
}


BallBearing();
