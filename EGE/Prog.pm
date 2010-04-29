use strict;
use warnings;

package EGE::Prog::SynElement;

sub new {
    my ($class, %init) = @_;
    my $self = { %init };
    bless $self, $class;
    $self;
}

sub to_lang {
    my ($self, $lang) = @_;
    die;
}

package EGE::Prog::Assign;

use base 'EGE::Prog::SynElement';

sub to_lang {
    my ($self, $lang) = @_;
    my $f = {
        Basic => '%s = %s',
        C => '%s = %s;',
        Pascal => '%s := %s;',
        Alg => '%s := %s',
        Perl => '$%s = %s;',
    };
    sprintf $f->{$lang}, $self->{var}, $self->{expr}->to_lang($lang);
}
sub run {
    my ($self, $env) = @_;
    $env->{$self->{var}} = $self->{expr}->run($env);
}

package EGE::Prog::BinOp;

use base 'EGE::Prog::SynElement';

sub op_to_lang { $_[0] }

sub to_lang {
    my ($self, $lang) = @_;
    join ' ',
        $self->{left}->to_lang($lang),
        op_to_lang($self->{op}, $lang),
        $self->{right}->to_lang($lang);
}

sub run {
    my ($self, $env) = @_;
    my $vl = $self->{left}->run($env);
    my $vr = $self->{right}->run($env);
    eval "$vl $self->{op} $vr";
}

package EGE::Prog::UnOp;

use base 'EGE::Prog::SynElement';

sub op_to_lang { $_[0] }

sub to_lang {
    my ($self, $lang) = @_;
    $self->{op} . $self->{arg}->to_lang($lang);
}

sub run {
    my ($self, $env) = @_;
    my $v = $self->{arg}->run($env);
    eval "$self->{op} $v";
}

package EGE::Prog::Var;

use base 'EGE::Prog::SynElement';

sub to_lang {
    my ($self, $lang) = @_;
    ($lang eq 'Perl' ? '$' : '') . $self->{name};
}

sub run {
    my ($self, $env) = @_;
    for ($env->{$self->{name}}) {
        defined $_ or die;
        return $_;
    }
}

package EGE::Prog::Const;

use base 'EGE::Prog::SynElement';

sub to_lang {
    my ($self, $lang) = @_;
    $self->{value};
}

sub run {
    my ($self, $env) = @_;
    $self->{value} + 0;
}

package EGE::Prog::RefConst;

use base 'EGE::Prog::SynElement';

sub to_lang {
    my ($self, $lang) = @_;
    ${$self->{ref}};
}

sub run {
    my ($self, $env) = @_;
    ${$self->{ref}} + 0;
}

package EGE::Prog::Block;

use base 'EGE::Prog::SynElement';

sub to_lang {
    my ($self, $lang) = @_;
    join "\n", map $_->to_lang($lang), @{$self->{statements}};
};

sub run {
    my ($self, $env) = @_;
    $_->run($env) for @{$self->{statements}};
}

package EGE::Prog;

sub make_expr {
    my ($src) = @_;
    if (ref $src =~ /^EGE::Prog::/) {
        return $src;
    }
    if (ref $src eq 'ARRAY') {
        if (@$src == 2) {
            return EGE::Prog::UnOp->new(
                op => $src->[0], arg => make_expr($src->[1]));
        }
        if (@$src == 3) {
            return EGE::Prog::BinOp->new(
                op => $src->[0],
                left => make_expr($src->[1]),
                right => make_expr($src->[2])
            );
        }
        die @$src;
    }
    if (ref $src eq 'SCALAR') {
        return EGE::Prog::RefConst->new(ref => $src);
    }
    if ($src =~ /^[A-Za-z][A-Za-z0-9]*$/) {
        return EGE::Prog::Var->new(name => $src);
    }
    return EGE::Prog::Const->new(value => $src);
}

sub make_block {
    my ($src) = @_;
    ref $src eq 'ARRAY' or die;
    my @s;
    for (my $i = 0; $i < @$src; $i += 3) {
        $src->[$i] eq '=' or die;
        push @s, EGE::Prog::Assign->new(
            var => $src->[$i + 1], expr => make_expr($src->[$i + 2])
        );
    }
    EGE::Prog::Block->new(statements => \@s);
}

sub lang_names() {{
  'Basic' => 'Бейсик',
  'Pascal' => 'Паскаль',
  'C' => 'Си',
  'Alg' => 'Алгоритмический',
}}

1;
