package OX::Meta::Role::Class;
use Moose::Role;

use List::MoreUtils qw(any);

has router => (
    is        => 'rw',
    isa       => 'Path::Router',
    predicate => 'has_router',
);

has router_config => (
    is        => 'rw',
    isa       => 'Bread::Board::Service',
    predicate => 'has_local_router_config',
);

has components => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Bread::Board::Service]',
    default => sub { [] },
    handles => {
        has_components => 'count',
        components     => 'elements',
        add_component  => 'push',
    },
);

has config => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Bread::Board::Service]',
    default => sub { [] },
    handles => {
        has_config => 'count',
        config     => 'elements',
        add_config => 'push',
    },
);

has mounts => (
    traits  => ['Hash'],
    isa     => 'HashRef[HashRef]',
    default => sub { {} },
    handles => {
        has_mounts  => 'count',
        mount_paths => 'keys',
        add_mount   => 'set',
        mount       => 'get',
    },
);

has route_builders => (
    traits  => ['Array'],
    isa     => 'ArrayRef[HashRef]',
    default => sub { [] },
    handles => {
        _add_route_builder => 'push',
        route_builders     => 'elements',
    }
);

sub has_any_config {
    my $self = shift;
    return any { $_->has_config }
           grep { Moose::Util::does_role($_, __PACKAGE__) }
           map { $_->meta }
           $self->linearized_isa;
}

sub get_all_config {
    my $self = shift;
    return map { $_->config }
           grep { Moose::Util::does_role($_, __PACKAGE__) }
           map { $_->meta }
           $self->linearized_isa;
}

sub has_any_components {
    my $self = shift;
    return any { $_->has_components }
           grep { Moose::Util::does_role($_, __PACKAGE__) }
           map { $_->meta }
           $self->linearized_isa;
}

sub get_all_components {
    my $self = shift;
    return map { $_->components }
           grep { Moose::Util::does_role($_, __PACKAGE__) }
           map { $_->meta }
           $self->linearized_isa;
}

sub has_router_config {
    my $self = shift;
    return any { $_->has_local_router_config }
           grep { Moose::Util::does_role($_, __PACKAGE__) }
           map { $_->meta }
           $self->linearized_isa;
}

sub full_router_config {
    my $self = shift;

    my @router_configs = map { $_->router_config }
                         grep { $_->has_local_router_config }
                         grep { Moose::Util::does_role($_, __PACKAGE__) }
                         map { $_->meta }
                         $self->linearized_isa;

    my %routes =       map { %{ $_->block->()    } } @router_configs;
    my %dependencies = map { %{ $_->dependencies } } @router_configs;
    return Bread::Board::BlockInjection->new(
        name         => 'config',
        block        => sub { \%routes },
        dependencies => \%dependencies,
    );
}

sub add_route_builder {
    my $self = shift;
    my %params = @_;
    $self->_add_route_builder(\%params);
}

sub route_builder_for {
    my $self = shift;
    my ($action_spec) = @_;

    for my $route_builder ($self->route_builders) {
        if ($route_builder->{condition}->($action_spec)) {
            return (
                $route_builder->{class},
                $route_builder->{route_spec}->($action_spec),
            );
        }
    }

    die "Unknown route spec $action_spec";
}

no Moose::Role;

1;
