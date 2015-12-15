# Copyright © 2010 Alexander S. Klenin
# Licensed under GPL version 2 or later.
# http://github.com/klenin/EGE
package EGE::Graph;

use strict;
use warnings;

use List::Util qw(min max);
use EGE::Html;
use EGE::Svg;

sub new {
    my ($class, %init) = @_;
    my $self = { %init };
    bless $self, $class;
    $self;
}

sub edge1 {
    my ($self, $v1, $v2, $w) = @_;
    $self->{vertices}->{$_} or die "Unknown vertex $_" for $v1, $v2;
    $self->{edges}->{$v1}->{$v2} = $w;
}

sub edge2 {
    my ($self, $v1, $v2, $w) = @_;
    $self->edge1($v1, $v2, $w);
    $self->{edges}->{$v2}->{$v1} = $w;
}

sub vertex_names { keys %{$_[0]->{vertices}} }

sub is_oriented {
    my ($self) = @_;
    my $e = $self->{edges};
    for my $src ($self->vertex_names) {
        exists $e->{$_}->{$src} or return 1 for keys %{$e->{$src}};
    }
    0;
}

sub html_matrix {
    my ($self) = @_;
    my @vnames = sort $self->vertex_names;
    my $r = html->row_n('td', '', @vnames);
    for (@vnames) {
        my $e = $self->{edges}->{$_};
        $r .= html->row_n('td', $_, map $_ || ' ', @$e{@vnames});
    }
    html->table($r, { border => 1 });
}

sub update_min_max {
    my ($value, $min, $max) = @_;
    $$min = $value if !defined($$min) || $value < $$min;
    $$max = $value if !defined($$max) || $value > $$max;
}

sub xy {
    my ($pt, $x, $y) = @_;
    ($x => $pt->[0], $y => $pt->[1]);
}

sub edges_string {
    my ($self) = @_;
    my $r = '';
    for my $src (sort $self->vertex_names) {
        my $edges = $self->{edges}{$src};
        my $e = '';
        for my $dest (sort keys %$edges) {
            my $w = $edges->{$dest} or next;
            $e .= "$dest=>$w,";
        }
        $r .= "$src=>{$e}," if $e;
    }
    $r;
}

sub as_svg {
    my ($self, %p) = @_;

    my $oriented = $p{oriented} // $self->is_oriented;

    my $radius = 5;
    my $font_size = 3 * $radius;

    my @vnames = $self->vertex_names;
    my @at = map $self->{vertices}{$_}{at}, @vnames;
    my $xmin = min map $_->[0] - $radius, @at;
    my $xmax = max map $_->[0] + $radius + $font_size, @at;
    my $ymin = min map $_->[1] - $radius - $font_size, @at;
    my $ymax = max map $_->[1] + $radius, @at;
    my ($xsize, $ysize) = ();

    my @texts;
    my $lines = '';
    for my $src (@vnames) {
        my $at = $self->{vertices}{$src}{at};
        push @texts, [ $src, x => $at->[0] + $radius, y => $at->[1] - 3 ];

        my $edges = $self->{edges}{$src};
        for my $e (keys %$edges) {
            my $dest_at = $self->{vertices}{$e}{at};
            my $c = [ map 0.5 * ($at->[$_] + $dest_at->[$_]), 0 .. 1 ];
            $at->[1] == $dest_at->[1] ?
                $c->[1] -= int($font_size / 2) :
                $c->[0] += 5;
            next if $at == $dest_at;
            my $vx = $dest_at->[0] - $at->[0];
            my $vy = $dest_at->[1] - $at->[1];
            my $len = sqrt($vx ** 2 + $vy ** 2);
            my $k = $radius / $len;
            my $dx = $vx * $k;
            my $dy = $vy * $k;
            my $x1 = $at->[0] + $dx;
            my $y1 = $at->[1] + $dy;
            my $x2 = $dest_at->[0] - $dx;
            my $y2 = $dest_at->[1] - $dy;
            $lines .= svg->line(
                x1 => $x1,
                y1 => $y1,
                x2 => $x2,
                y2 => $y2,
                stroke => 'black',
                'stroke-width' => 1,
                ($oriented ? ('marker-end' => 'url(#arrow)') : ()),
            );
            push @texts, [ $edges->{$e}, xy($c, qw(x y)) ];
        }
    }
    svg->start([ $xmin, $ymin, $xmax - $xmin, $ymax - $ymin ]) .
    ($oriented ? svg->defs(svg->marker(
        svg->path(d => 'M0,0 L4,6 L0,12 L18,6 z', fill => 'black'),
        id => 'arrow',
        markerWidth => 10, markerHeight => 10,
        refX => 18, refY => 6,
        orient => 'auto',
        markerUnits => 'userSpaceOnUse',
        viewBox => '0 0 20 20',
    )) : '').
    svg->g(
        [ map svg->circle(xy($_, qw(cx cy)), r => $radius), @at ],
        fill => 'black', stroke => 'black',
    ) .
    svg->g($lines) .
    svg->g([ map svg->text(@$_), @texts ], 'font-size' => $font_size) .
    svg->end;
}

1;
