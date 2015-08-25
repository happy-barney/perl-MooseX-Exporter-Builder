# ============================================================================«
package MooseX::App;
# ============================================================================«

use 5.010;
use utf8;
use strict;
use warnings;

our $AUTHORITY = 'cpan:MAROS';
our $VERSION = '1.33';

use MooseX::App::Meta::Role::Attribute::Option;
use MooseX::App::Exporter qw(app_usage app_description app_base app_fuzzy app_strict app_prefer_commandline app_permute option parameter);
use MooseX::App::Message::Envelope;

use Scalar::Util qw(blessed);
use MooseX::Exporter::Builder;

also 'Moose';
with_import {
    my ($next, $class, @plugins) = @_;

    MooseX::App::Exporter->process_plugins (scalar caller, @plugins);

    $class->$next ();
};

with_init_meta {
    my ($class, %args) = @_;

    $args{roles}        = ['MooseX::App::Role::Base'];
    $args{metaroles}    = {
        class               => [
            'MooseX::App::Meta::Role::Class::Base',
            'MooseX::App::Meta::Role::Class::Documentation'
        ],
        attribute           => ['MooseX::App::Meta::Role::Attribute::Option'],
    };

    return MooseX::App::Exporter->process_init_meta(%args);
};

with_meta app_command_name => sub (&) {
    my ( $meta, $namesub ) = @_;
    return $meta->app_command_name($namesub);
};

with_meta app_command_register => sub (%) {
    my ( $meta, %commands ) = @_;

    foreach my $command (keys %commands) {
        $meta->command_register($command,$commands{$command});
    }
    return;
};

with_meta app_namespace => sub (@) {
    my ( $meta, @namespaces ) = @_;
    return $meta->app_namespace( \@namespaces );
};

as_is new_with_command => sub {
    my ($class,@args) = @_;

    ...;
};

# Variant 1: Reexport functions exported by other module
# use MooseX::App::Exporter qw(app_usage app_description app_base app_fuzzy app_strict app_prefer_commandline app_permute option parameter);
with_meta 'app_usage';
with_meta 'app_description';
with_meta 'app_base';
with_meta 'app_fuzzy';
with_meta 'app_strict';
with_meta 'app_prefer_commandline';
with_meta 'app_permute';
with_meta 'option';
with_meta 'parameter';

# Variant 2: Import and export foreign functions
# use MooseX::App::Exporter;
with_meta app_usage              => \ &MooseX::App::Exporter::app_usage;
with_meta app_base               => \ &MooseX::App::Exporter::app_base;
with_meta app_fuzzy              => \ &MooseX::App::Exporter::app_fuzzy;
with_meta app_strict             => \ &MooseX::App::Exporter::app_strict;
with_meta app_prefer_commandline => \ &MooseX::App::Exporter::app_prefer_commandline;
with_meta app_permute            => \ &MooseX::App::Exporter::app_permute;
with_meta option                 => \ &MooseX::App::Exporter::option;
with_meta parameter              => \ &MooseX::App::Exporter::parameter;

no Moose;
1;

