package WebAPI::DBIC::Serializer::Base;

=head1 NAME

WebAPI::DBIC::Serializer::Base - what will I become?

=cut

use Moo;


has resource => (
    is => 'ro',
    required => 1,
    weak_ref => 1,
    handles => [qw(
        type_namer
        get_url_template_for_set_relationship
        get_url_for_item_relationship
        uri_for
        set
        prefetch
        param
        render_item_as_plain_hash
        add_params_to_url
        path_for_item
        web_machine_resource
    )],
);

1;
