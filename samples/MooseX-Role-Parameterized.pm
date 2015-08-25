
package MooseX::Role::Parameterized;

use MooseX::Exporter::Builder;
use Carp 'confess';
use Moose::Util 'find_meta';
use namespace::clean;

our $CURRENT_METACLASS;

sub current_metaclass { $CURRENT_METACLASS }

also 'Moose::Role';
role_metaroles role => 'MooseX::Role::Parameterized::Meta::Trait::Parameterizable';

with_meta_lookup {
    my $for = shift;
    current_metaclass() || find_meta($for);
};

with_caller parameter   => sub {
    my $caller = shift;
    ...;
};

with_caller role        => sub (&) {
    my ($caller, $role_generator) = @_;

    isa $role_generator, 'CodeRef';

    confess "'role' may not be used inside of the role block"
        if current_metaclass && current_metaclass->genitor->name eq $caller;

    find_meta($caller)->role_generator($role_generator);
};

with_meta   method      => sub {
    my ($meta, $name, $body) = @_;
    ...;
};

with_meta   with        => sub {
    local $CURRENT_METACLASS = undef;
    Moose::Role::with(@_);
};

1;

