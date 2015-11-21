
package MooseX::Exporter::Builder v0.1.0;

use strict;
use warnings FATAL => 'all';
use feature ':5.10';

our $AUTHORITY = 'cpan:BARNEY';

require Moose::Exporter;
require Moose::Util::TypeConstraints;

use Sub::Install qw( install_sub );
use Sub::Uplevel qw( uplevel );

my ($import, $unimport, $init_meta) = Moose::Exporter->build_import_methods (
    as_is     => [
        'also',
        'as_is',
        'with_meta',
        'with_import',
        'with_unimport',
        'with_init_meta',
        'with_meta_lookup',
        'with_caller',
        'role_metaroles',
        'isa',
    ],
    install   => [ 'unimport' ],
);

sub export_params {                      # ; get/init setup for caller module
    my $package = $_[0] // scalar caller 1;
    state $cache = {};

    unless ($cache->{$package}) {
        my $retval = $cache->{$package} = {
            exporting_package => $package,
        };

        $retval->{with_import}    = sub {
            uplevel 1, $retval->{sub_import}, @_
        };

        $retval->{with_unimport}  = sub {
            uplevel 1, $retval->{sub_unimport}, @_
        };

        $retval->{with_init_meta} = sub {
            uplevel 1, $retval->{sub_init_meta}, @_ if $retval->{sub_init_meta}
        };
    }

    $cache->{$package};
}

sub install_into {                       # ; install procedure into caller package
    my ($package, $name, $sub) = @_;

    Sub::Install::install_sub ({
        code => $sub,
        into => $package,
        as   => $name,
    });
}

sub build_exporter {                     # ;
    my ($params) = @_;

    unless (defined $params->{sub_import}) {
        my %def = %$params;
        delete @def{qw[ with_import with_unimport with_init_meta ]};

        @$params{qw[ sub_import sub_unimport sub_init_meta ]}
          = Moose::Exporter->build_import_methods (%$params);
    };
}

sub caller_import {                      # ;
    my ($class, @params) = @_;
    my $params = export_params ($class);

    build_exporter ($params);
    uplevel 1, $params->{with_import}, $class, @params;
}

sub caller_unimport {                    # ;
    my ($class, @params) = @_;
    my $params = export_params ($class);

    build_exporter ($params);
    uplevel 1, $params->{with_unimport}, $class, @params;
}

sub caller_init_meta {                   # ;
    my ($class, @params) = @_;
    my $params = export_params ($class);

    build_exporter ($params);
    uplevel 1, $params->{with_init_meta}, $class, @params;
}

sub import {                             # ; import method - registry on_scope_end
    my ($class, @params) = @_;
    my $export_params = export_params;

    install_into ($export_params->{exporting_package}, import    => \&caller_import);
    install_into ($export_params->{exporting_package}, unimport  => \&caller_unimport);
    install_into ($export_params->{exporting_package}, init_meta => \&caller_init_meta);

    $class->$import ({ into => scalar caller });
}

sub also {                               # ; add listed packages into 'also'
    push @{ export_params->{also} //= [] }, @_;
}

sub as_is {                              # ; create and export as_is
    my ($name, $sub) = @_;

    install_into (export_params->{exporting_package}, $name, $sub)
      if $sub;

    push @{ export_params->{as_is} //= [] }, $name;
}

sub with_meta {                          # ; create and export with_meta
    my ($name, $sub) = @_;

    install_into (export_params->{exporting_package}, $name, $sub)
      if $sub;

    push @{ export_params->{with_meta} //= [] }, $name;
}

sub with_import (&) {                    # ;
    my ($sub) = @_;

    my $current = export_params->{with_import};
    # 1: $sub; 2: wrapper
    my $next = sub { uplevel 2, $current, @_ };
    export_params->{with_import} = sub { uplevel 1, $sub, $next, @_ };
}

sub with_unimport (&) {                  # ;
    my ($sub) = @_;

    my $current = export_params->{with_unimport};
    # 1: $sub; 2: wrapper
    my $next = sub { uplevel 2, $current, @_ };
    export_params->{with_unimport} = sub { uplevel 1, $sub, $next, @_ };
}

sub with_init_meta (&) {                 # ;
    my ($sub) = @_;

    require Sub::Name;
    Sub::Name::subname ('init_meta', $sub);
    install_into (export_params->{exporting_package}, 'init_meta', $sub);
}

sub with_meta_lookup (&) {
    my ($sub) = @_;

    export_params->{meta_lookup} = $sub;
}

sub role_metaroles {                     # ;
    my (%hash) = @_;
    return unless @_;

    my $hash = export_params->{role_metaroles};

    while (my ($key, $value) = each %hash) {
        my @list = 'ARRAY' eq ref $value ? @$value : $value;
        eval "use $_" for @list;
        push @{ $hash->{$key} //= [] }, @list;
    }
}

sub with_caller {                        # ; create and export with_caller
    my ($name, $sub) = @_;

    install_into (export_params->{exporting_package}, $name, $sub)
      if $sub;

    push @{ export_params->{with_caller} //= [] }, $name;
}

sub isa {                                # ;
    my ($expression, $type) = @_;

    my $constraint = Moose::Util::TypeConstraints::find_type_constraint ($type);

    Moose->throw_error ("${constraint}: Type constraint not found")
      unless $constraint;

    Moose->throw_error ("${constraint}: expression doesn't match"
      # Validate returns false on success, true on failed ...
      if $constraint->validate ($expression);
}

package MooseX::Exporter::Builder;

1;

__END__

=pod

=head1 NAME

MooseX::Exporter::Builder - Syntax sugar to build (and export) Moose helpers even easier

=head1 SYNOPSIS

   package My::MooseX;
   use MooseX::Exporter::Builder;
   use Other::Exporter qw( bar );

   also 'Moose';
   as_is as => sub ($) { shift };
   with_meta foo => sub {
       my ($meta, ...) = @_;
       ...;
   };
   with_meta 'bar';                      # Reexport

Same with plain Moose::Exporter

   package My::MooseX;
   use Moose::Exporter;

   Moose::Exporter->build_import_methods (
       as_is     => [ 'as' ],
       with_meta => [ 'foo', 'bar' ],
       also      => [ 'Moose' ],
       install   => [ 'import', 'unimport', 'init_meta' ],
   );
   sub as (&) { shift }
   sub foo {
       my ($meta, ...) = @_;
       ...;
   }

=head1 DESCRIPTION

Helper package providing some syntax sugar and (important for lazy people like me)
maintains Moose::Exporter automatically.

=head1 HELPERS

=head2 also @package_names

puts listed package name(s) into C<also> array of L<Moose::Exporter>

=head2 as_is name => sub { ... }

Create sub C<name> in caller package and append it into C<as_is> array of L<Moose::Exporter>

=head2 with_meta name => sub { ... }

Create sub C<name> in caller package and append it into C<with_meta> array of L<Moose::Exporter>

=head2 with_import { ... }

Install C<import> function.
Unlike regular import function it receives next import function as first argument.

If not used, let L<Moose::Exporter> to install C<import> function

   with_import {
       my ($next, @args) = @_;
       ...;
       $next->(@args);
   }

TODO: ???

=head2 with_unimport { }

Similar to C<with_import> but for C<unimport> function

=head2 with_init_meta { }

Similar to C<with_import> but for C<init_meta> function

=head2 isa ($expr, $type)

Perform check whether C<$expression> matches Moose type C<$type>, see L<Moose::Manual::Types>

   sub {
       my ($name, $code) = @_;
       isa $name, 'My::Type::Name';
       isa $code, 'CodeRef';
   }

=head1 AUTHOR

Branislav Zahradnik <barney@cpan.org>

=head1 REPOSITORY

https://github.com/happy-barney/perl-MooseX-Exporter-Builder

