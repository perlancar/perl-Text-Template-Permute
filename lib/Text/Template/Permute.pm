package Text::Template::Permute;

use 5.010001;
use strict;
use warnings;

use Permute::Unnamed ();

# AUTHORITY
# DATE
# DIST
# VERSION

sub new {
    my $class = shift;

    bless {}, $class;
}

sub _process_directive {
    my $self = shift;
    my $directive = shift;

    my ($command, $opts, $args) = $directive =~ /\A(\w+)\s*([^:]*)\s*:\s*(.+)\z/
        or die "Invalid directive syntax '$directive', please use COMMAND[OPTIONS]: ...";
    #use DD; dd {command=>$command, opts=>$opts, args=>$args};
    if ($command eq 'comment') {
        return ();
    } elsif ($command eq 'permute') {
        my @items = split /\|/, $args;
        push @{ $self->{_permute_args} }, \@items;
        my $i = $self->{_permute_idx}++;
        return (sub { $self->{_permute_items}[$_[0]][$i] });
    } elsif ($command eq 'pick') {
        my @choices = split /\|/, $args;
       if ($opts eq 'once') {
           return ($choices[rand @choices]);
        } else {
            return (sub { $choices[rand @choices] });
        }
    } else {
        die "Unknown command '$command'";
    }
}

sub template {
    my $self = shift;

    if (@_) {
        my $template = shift;
        $self->{template} = $template;
        $self->{_permute_args} = [];
        $self->{_var_array} = [];
        $self->{_var_idx} = {};
        $self->{_idx} = 0;
        $self->{_template_parts} = [];
        $self->{_permute_idx} = 0;
        $template =~ s{(    # 1. whole match
            \{\{(.*?)\}\} | # 2.   directive
            (?:[^\{]+) |    # -.   normal text
            (?:[\{\}]+)     # -.   normal text
        )
        }{
            if (defined $2) {
                push @{ $self->{_template_parts} }, $self->_process_directive($2);
            } else {
                push @{ $self->{_template_parts} }, $1;
            }

        }egsx;
    }
    return $self->{template};
}

sub _fill {
    my $self = shift;
    my $i = shift;
    my @res;
    for my $part (@{ $self->{_template_parts} }) {
        if (ref $part) {
            push @res, $part->($i);
        } else {
            push @res, $part;
        }
    }
    join "", @res;
}

sub var {
    my $self = shift;

    my $name = shift;
    my $val;
    if (exists $self->{_var_idx}{$name}) {
        $val = $self->{vars}{$name};
    } else {
        die "Variable '$name' not mentioned in template";
    }
    if (@_) {
        $val = shift;
        $self->{vars}{$name} = $val;
        $self->{_var_array}[ $self->{_var_idx}{$name} - 1] = $val;
    }
    $val;
}

sub process {
    #no warnings 'uninitialized';

    my $self = shift;

    # generate the permutations of args
    $self->{_permute_items} = [];
    if (@{ $self->{_permute_args} }) {
        $self->{_permute_items} = Permute::Unnamed::permute_unnamed(@{ $self->{_permute_args} });
    } else {
        push @{ $self->{_permute_items} }, [];
    }
    #use DD; dd $self->{_permute_items};

    # generate the permutations of text
    my @res;
    for my $i (0 .. $#{ $self->{_permute_items} }) {
        push @res, $self->_fill($i);
    }

    @res;
}

1;
#ABSTRACT: Template for generating permutation of text

=for Pod::Coverage ^(.+)$

=head1 SYNOPSIS

 use Text::Template::Permute;

 my $td = Text::Template::Permute->new(
 );

 $td->template(<<'TEMPLATE');
 Create an image of the boy and animal together.
 {{comment: pose}}{{pick: The boy is standing, holding the animal|The boy is sitting, the animal is standing on the boy's lap}}.
 {{comment: clothing}}{{permute: |Change the boy's clothes to random children clothing.}}
 {{comment: size clue}}The animal is only as large as the boy's hand.
 {{comment: style, mood}}Make sure style is 3d cartoon.
 Horizontal angle: {{pick once: front view|three quarter view}}.
 Plain white background.
 TEMPLATE

 my @res = $td->process;


=head1 DESCRIPTION


=head1 SEE ALSO

L<Text::Glob::Expand>
