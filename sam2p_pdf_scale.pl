#! /bin/sh
eval '(exit $?0)' && eval 'PERL_BADLANG=x;PATH="$PATH:.";export PERL_BADLANG\
 PATH;exec perl -x -S -- "$0" ${1+"$@"};#'if 0;eval 'setenv PERL_BADLANG x\
;setenv PATH "$PATH":.;exec perl -x -S -- "$0" $argv:q;#'.q
#!perl -w
+push@INC,'.';$0=~/(.*)/s;do(index($1,"/")<0?"./$1":$1);die$@if$@__END__+if 0
;#Don't touch/remove lines 1--7: http://www.inf.bme.hu/~pts/Magic.Perl.Header
#
# sam2p_pdf_scale.pl: scale PDF created by sam2p to page size
# by pts@fazekas.hu at Sat Jun  6 17:16:17 CEST 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#s
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

use integer;
use strict;
die "Usage: $0 <page-width-bp> <page-height-bp> <input.pdf> [<output.pdf>]\n".
    "This program reads a PDF generated by sam2p, ".
    "and scales it to page size.\n" if @ARGV != 3 and @ARGV != 4;
die "page-width not a nonnegative number\n" if $ARGV[0] !~ m@\A[\d.]+\Z(?!\n)@;
die "page-height not a nonnegative number\n"
    if $ARGV[1] !~ m@\A[\d.]+\Z(?!\n)@;
sub float2str($) {
  no integer;
  my $F = $_[0] + 0;
  $F = "$F";
  if (index($F, 'e') >= 0) {
    $F = sprintf("%.20f", $F);
    $F =~ s@[.]?0+\Z@@;
  }
  $F
}
#** Desired page size dimensions. Must be integers, measured in bp (inch/72).
my $dwidth = float2str($ARGV[0]);
my $dheight = float2str($ARGV[1]);
my $outfn = @ARGV == 4 ? $ARGV[3] : $ARGV[2];
my $F;
die "cannot open input PDF: $ARGV[2]: $!\n" if !open($F, '<', $ARGV[2]);
my $S = join('', <$F>);
die if !close($F);
die "sam2p PDF syntax error (no cm)\n" if $S!~m@\n((\d+) 0 0 (\d+) 0 0 cm\b)@g;
my $cm_at = pos($S) - length($1);
my $cm_size = length($1);
my $iwidth = $2 + 0;
my $iheight = $3 + 0;
die "sam2p PDF image error (empty image)\n" if $iwidth < 0 or $iheight < 0;
my $rest_at = rindex($S, "\nendstream\n") + 1;
die "sam2p PDF syntax error (no endstream)\n" if $rest_at <= $cm_at;
pos($S) = $rest_at;
die "sam2p PDF syntax error (boxes not found)\n" if
    $S!~m@(/MediaBox\s*\[0 0 (\d+) (\d+)\]\s*/CropBox\s*\[0 0 (\d+) (\d+)\])@g;
my $boxes_at = pos($S) - length($1);
my $boxes_size = length($1);
die "sam2p PDF syntax error (image size mismatch)\n" if
    $2 ne $iwidth or $3 ne $iheight or
    $4 ne $iwidth or $5 ne $iheight;
my $boxes_new =
    "/MediaBox[0 0 $dwidth $dheight]\n/CropBox[0 0 $dwidth $dheight]";
substr($S, $boxes_at, $boxes_size) = $boxes_new;
my($cwidth, $cheight);
my($xshift, $yshift);
{ no integer;
  my $aheight = $iheight * $dwidth / $iwidth;
  my $bwidth  = $iwidth * $dheight / $iheight;
  if ($aheight <= $dheight) { ($cwidth, $cheight) = ($dwidth, $aheight) }
  else { ($cwidth, $cheight) = ($bwidth, $dheight) }
  $xshift = ($dwidth - $cwidth) / 2;
  $yshift = ($dheight - $cheight) / 2;
}
my $cm_new = float2str($cwidth)." 0 0 ".float2str($cheight)." ".
    float2str($xshift)." ".float2str($yshift)." cm";
substr($S, $cm_at, $cm_size) = $cm_new;
pos($S) = 0;
if ($S =~ m@\n<</Length ((\d+)>>\nstream\nq\n)@g and pos($S) == $cm_at) {
  substr($S, pos($S) - length($1), length($2)) =
      sprintf("%".length($2)."d", $2 + length($cm_new) - $cm_size);
}
pos($S) = $boxes_at + length($boxes_new) + length($cm_new) - $cm_size;
die "sam2p PDF syntax error (xref not found)\n" if
    $S!~m@\sendobj\n(xref\n0 (\d+)\n0000000000 65535 f \n)@g;
my $xref_at = pos($S) - length($1);
my $obj_count = $2 - 1;
my $ofss_at = pos($S);
for (my $I = 1; $I <= $obj_count; ++$I) {
  my $xrefe_at = $ofss_at + ($I - 1) * 20;
  my $xrefe = substr($S, $xrefe_at, 20);
  die "sam2p PDF syntax error (xref entry $I bad)\n" if
      $xrefe!~m@\A(\d{10}) 00000 n \n\Z(?!\n)@;
  my $ofs = $1 + 0;
  $ofs += (
     ($ofs >= $boxes_at) ? length($boxes_new) - $boxes_size +
                           length($cm_new) - $cm_size :
     ($ofs >= $cm_at) ?    length($cm_new) - $cm_size : 0);
  substr($S, $xrefe_at, 20) = sprintf("%010d 00000 n \n", $ofs);
}
pos($S) = $ofss_at + $obj_count * 20;
die "sam2p PDF syntax error (startxref not found)\n" if
    $S!~s@\nstartxref\n(\d+)\n@\nstartxref\n$xref_at\n@;
die "cannot open output PDF: $outfn: $!\n" if !open($F, '>', $outfn);
die if !print($F $S);
die if !close($F);
