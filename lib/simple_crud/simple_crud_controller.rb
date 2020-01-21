require 'byebug'
require 'active_support/all'
require_relative 'valid_method_checker'
require_relative 'policy_checker'
require_relative 'serializer_checker'
module SimpleCrudController
  cattr_accessor :params, :permitted

  def simple_crud(all_parameters = {})
    all_methods = %i[show index destroy create update]
    methods_to_create = all_parameters[:only] || all_methods - [all_parameters[:except]]
    methods_to_create.each do |method|
      simple_crud_for(method, all_parameters.except(:only, :except))
    end
  end

  # Possible options:
  ### authorize: use pundit to automatically check for authorization
  ### paginate: use wor-paginate to paginate the list
  ### authenticate: use devise to authenticate
  ### serializer: use a particular serializer (both each_serializer and serializer)
  ### filter: use toscha-filterable to filter
  def simple_crud_for(method, parameters = {})
    parameters = set_parameters(parameters)
    klass = simple_crud_controller_model
    ValidMethodChecker.new.check(method)
    PolicyChecker.new.check(parameters, simple_crud_controller_model)
    SerializerChecker.new.check(parameters)
    define_method(method, send("crud_lambda_for_#{method}", klass, parameters))
    write_metadata(method, parameters)
  end

  def set_parameters(parameters)
    parameters.with_defaults(authorize: true, paginate: true, authenticate: true,
                             serializer: nil, filter: true)
  end

  def write_metadata(method, parameters)
    @simple_crud_metadata ||= {}
    @simple_crud_metadata[method] = parameters
  end

  def crud_lambda_for_show(klass, parameters = {})
    lambda do
      authenticate_user! if parameters[:authenticate]
      requested = klass.find(params[:id])

      options = {}.merge(serializer: parameters[:serializer]).compact
      authorize requested if parameters[:authorize]
      render({ json: requested }.merge(options))
    end
  end

  def crud_lambda_for_index(query, parameters = {})
    lambda do
      authenticate_user! if parameters[:authenticate]
      authorize query.new if parameters[:authorize]
      paginate = parameters[:paginate]
      serializer = parameters[:serializer]
      options = {}.merge(each_serializer: serializer).compact
      if parameters[:filter]
        byebug
        query = query.filter(send("#{self.class.simple_crud_controller_model.to_s.underscore}_filters"))
      end
      paginate ? (render_paginated query, options) : render({ json: query.all }.merge(options))
    end
  end

  def crud_lambda_for_create(klass, parameters = {})
    lambda do
      authenticate_user! if parameters[:authenticate]
      permitted_params = send("#{self.class.simple_crud_controller_model.to_s.underscore}_params")
      authorize klass.new(permitted_params) if parameters[:authorize]
      render json: klass.create!(permitted_params), status: :created
    end
  end

  def crud_lambda_for_update(klass, parameters = {})
    lambda do
      authenticate_user! if parameters[:authenticate]
      requested = klass.find(params[:id])
      authorize requested if parameters[:authorize]
      permitted_params = send("#{self.class.simple_crud_controller_model.to_s.underscore}_params")
      render json: requested.update!(permitted_params)
    end
  end

  def crud_lambda_for_destroy(klass, parameters = {})
    lambda do
      authenticate_user! if parameters[:authenticate]
      requested = klass.find(params[:id])
      authorize requested if  parameters[:authorize]
      render json: klass.find(params[:id]).destroy
    end
  end

  def simple_crud_controller_model
    to_s.split('::').last.sub('Controller', '').singularize.classify.constantize
  end
end
