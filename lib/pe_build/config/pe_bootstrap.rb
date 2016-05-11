require 'pe_build/config/global'
require 'pe_build/util/version_string'

class PEBuild::Config::PEBootstrap < PEBuild::Config::Global
  # Version at which support for installing agents was deprecated.
  AGENT_DEPRECATED_VERSION  = '2015.2.0'

  # @!attribute master
  #   @return [String] The DNS hostname of the Puppet master for this node.
  #   @since 0.1.0
  attr_accessor :master

  # @!attribute answer_file
  #   @return [String] The path to a user specified answer_file file (Optional)
  #   @since 0.1.0
  attr_accessor :answer_file

  # @!attribute answer_extras
  #   @return [Array<String>] An array of additional answer strings that will
  #     be appended to the answer file. (Optional)
  #   @since 0.11.0
  attr_accessor :answer_extras

  # @!attribute verbose
  #   @return [TrueClass, FalseClass] if stdout will be displayed when installing
  #   @since 0.1.0
  attr_accessor :verbose

  # @!attribute role
  #   @return [Symbol] The type of the PE installation role. One of [:master, :agent]
  #   @since 0.1.0
  attr_accessor :role

  # @api private
  VALID_ROLES = [:agent, :master]

  # @!attribute relocate_manifests
  #   @return [TrueClass, FalseClass] if the puppet master should use manifests
  #                                   out of the vagrant directory.
  #   @since 0.1.0
  attr_accessor :relocate_manifests

  # @!attribute [rw] autosign
  #   Configure the certificates that will be autosigned by the puppet master.
  #
  #   @return [TrueClass] All CSRs will be signed
  #   @return [FalseClass] The autosign config file will be unmanaged
  #   @return [Array<String>] CSRs with the given addresses
  #
  #   @see http://docs.puppetlabs.com/guides/configuring.html#autosignconf
  #
  #   @since 0.4.0
  #
  attr_accessor :autosign

  # @api private
  VALID_AUTOSIGN_VALUES = [TrueClass, FalseClass, Array]

  def initialize
    super
    @role        = UNSET_VALUE
    @verbose     = UNSET_VALUE
    @master      = UNSET_VALUE
    @answer_file = UNSET_VALUE
    @answer_extras = UNSET_VALUE

    @relocate_manifests = UNSET_VALUE

    @autosign = UNSET_VALUE
  end

  include PEBuild::ConfigDefault

  # Finalize all configuration variables
  #
  # @note This does _not_ finalize values for config options inherited from the
  #   global configuration; it's assumed that the late configuration merging in
  #   the provisioner will handle that.
  def finalize!
    set_default :@role,        :agent
    set_default :@verbose,     true
    set_default :@master,      'master'
    set_default :@answer_file, nil
    set_default :@answer_extras, []
    set_default :@autosign,    (@role == :master)

    set_default :@relocate_manifests, false

    # The value of role is normalized to a symbol so that users don't have to
    # know the underlying representation, and we don't have to cast everything
    # to a string and symbols later on.
    #
    # We also need to run this after a default was set, otherwise we'll try to
    # normalize UNSET_VALUE
    @role = @role.intern
  end

  # @param machine [Vagrant::Machine]
  def validate(machine)
    h = super

    errors = []

    validate_role(errors, machine)
    validate_verbose(errors, machine)
    validate_master(errors, machine)
    validate_answer_file(errors, machine)
    validate_answer_extras(errors, machine)
    validate_relocate_manifests(errors, machine)
    validate_autosign(errors, machine)
    validate_version(errors, machine)

    errors |= h.values.flatten
    {"PE Bootstrap" => errors}
  end

  private

  def validate_role(errors, machine)
    unless VALID_ROLES.any? {|sym| @role == sym.intern}
      errors << I18n.t(
        'pebuild.config.pe_bootstrap.errors.unknown_role',
        :role        => @role.inspect,
        :known_roles => VALID_ROLES,
      )
    end
  end

  def validate_verbose(errors, machine)
    unless @verbose == !!@verbose
      errors << I18n.t(
        'pebuild.config.pe_bootstrap.errors.malformed_verbose',
        :verbose => @verbose.inspect,
      )
    end
  end

  def validate_master(errors, machine)
    unless @master.is_a? String
      errors << "'master' must be a string containing the address of the master, got a #{@master.class}"
    end
  end

  def validate_answer_file(errors, machine)
    if @answer_file and !File.readable? @answer_file
      errors << "'answers_file' must be a readable file"
    end
  end

  def validate_answer_extras(errors, machine)
    unless @answer_extras.is_a? Array
      errors << I18n.t(
        'pebuild.config.pe_bootstrap.errors.invalid_answer_extras',
        :class => @answer_extras.class
      )
    end
  end

  def validate_relocate_manifests(errors, machine)
    if @relocate_manifests and not @role == :master
      errors << "'relocate_manifests' can only be applied to a master"
    end
  end

  def validate_autosign(errors, machine)
    if (@autosign and @role != :master)
      errors << I18n.t(
        'pebuild.config.pe_bootstrap.errors.invalid_autosign_role',
        :role => @role
      )
    end

    unless VALID_AUTOSIGN_VALUES.include?(@autosign.class)
      errors << I18n.t(
        'pebuild.config.pe_bootstrap.errors.invalid_autosign_class',
        :autosign_class   => @autosign.class,
        :autosign_classes => VALID_AUTOSIGN_VALUES,
      )
    end
  end

  def validate_version(errors, machine)
    return unless @role.intern == :agent

    if PEBuild::Util::VersionString.compare(@version, AGENT_DEPRECATED_VERSION) >= 0
      machine.ui.warn I18n.t(
        'pebuild.config.pe_bootstrap.warnings.agent_role_deprecated',
        :version         => @version
      )
    end
  end
end
