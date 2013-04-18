package Slic3r::Layer;
use Moo;

use List::Util qw(first);
use Slic3r::Geometry qw(scale);
use Slic3r::Geometry::Clipper qw(union_ex);

has 'id'                => (is => 'rw', required => 1, trigger => 1); # sequential number of layer, 0-based
has 'object'            => (is => 'ro', weak_ref => 1, required => 1);
has 'regions'           => (is => 'ro', default => sub { [] });
has 'slicing_errors'    => (is => 'rw');

has 'slice_z'           => (is => 'ro', required => 1); # Z used for slicing in scaled coordinates
has 'print_z'           => (is => 'ro', required => 1); # Z used for printing in scaled coordinates
has 'height'            => (is => 'ro', required => 1); # layer height in unscaled coordinates

# collection of expolygons generated by slicing the original geometry;
# also known as 'islands' (all regions are merged here)
has 'slices'            => (is => 'rw');

# ordered collection of extrusion paths to fill surfaces for support material
has 'support_islands'           => (is => 'rw');
has 'support_fills'             => (is => 'rw');
has 'support_contact_fills'     => (is => 'rw');

sub _trigger_id {
    my $self = shift;
    $_->_trigger_layer for @{$self->regions || []};
}

# layer height of contact paths in unscaled coordinates
sub support_material_contact_height {
    my $self = shift;
    
    return $self->height if $self->id == 0;
    
    # TODO: check what upper region applies instead of considering the first one
    my $upper_layer = $self->object->layers->[ $self->id + 1 ] // $self;
    my $h = ($self->height + $upper_layer->height) - $upper_layer->regions->[0]->extruders->{infill}->bridge_flow->width;
    
    # If layer height is less than half the bridge width then we'll get a negative height for contact area.
    # The optimal solution would be to skip some layers during support material generation, but for now
    # we'll apply a (dirty) workaround that should still work.
    if ($h <= 0) {
        $h = $self->height;
    }
    
    return $h;
}

# Z used for printing support material contact in scaled coordinates
sub support_material_contact_z {
    my $self = shift;
    return $self->print_z - ($self->height - $self->support_material_contact_height) / &Slic3r::SCALING_FACTOR;
}

sub region {
    my $self = shift;
    my ($region_id) = @_;
    
    for (my $i = @{$self->regions}; $i <= $region_id; $i++) {
        $self->regions->[$i] //= Slic3r::Layer::Region->new(
            layer   => $self,
            region  => $self->object->print->regions->[$i],
        );
    }
    
    return $self->regions->[$region_id];
}

# merge all regions' slices to get islands
sub make_slices {
    my $self = shift;
    
    # optimization for single-region layers
    my @regions_with_slices = grep { @{$_->slices} } @{$self->regions};
    if (@regions_with_slices == 1) {
        $self->slices([ map $_->expolygon, @{$regions_with_slices[0]->slices} ]);
        return;
    }
    
    $self->slices(union_ex([ map $_->p, map @{$_->slices}, @{$self->regions} ]));
}

sub make_perimeters {
    my $self = shift;
    Slic3r::debugf "Making perimeters for layer %d\n", $self->id;
    $_->make_perimeters for @{$self->regions};
}

sub support_islands_enclose_line {
    my $self = shift;
    my ($line) = @_;
    return 0 if !$self->support_islands;   # why can we arrive here if there are no support islands?
    return (first { $_->encloses_line($line) } @{$self->support_islands}) ? 1 : 0;
}

1;