require 'spec_helper'
require 'my_docker_rake/utilities'
require 'tempfile'
include MyDockerRake::Utilities


SILENCE_OPTIONS = {verbose: false}

shared_context 'run_container' do
  let! (:container) {
    `docker run -d busybox sh -c 'while true; do echo "hello world"; sleep 1; done'`.chomp
  }

  after(:each) do
    system <<-EOC
      ( docker kill #{container}; \
        docker rm #{container} ) \
      >/dev/null 2>&1
    EOC
  end
end


shared_context 'build_image' do
  let (:image) { 'my_docker_rake/testing' }

  around(:each) { |example|
    system <<-EOC
      echo "from busybox\nRUN echo 'hello world'" \
      | docker build -t #{image} - >/dev/null 2>&1
    EOC

    example.run

    system <<-EOC
      docker rmi >/dev/null 2>&1
    EOC
  }
end


describe MyDockerRake::Utilities, '#running_container?' do
  include_context 'run_container'

  context 'when container is running' do
    it { running_container?(container).should be_true }
  end

  context 'when container is not running' do
    before { `docker kill #{container}` }

    it { running_container?(container).should be_false }
  end

  context 'when container does not exist' do
    it { running_container?('_no_such_container').should be_false }
  end
end


describe MyDockerRake::Utilities, '#has_container?' do
  include_context 'run_container'

  context 'when container is running' do
    it { has_container?(container).should be_true }
  end

  context 'when container is not running' do
    before { `docker kill #{container}` }

    it { has_container?(container).should be_true }
  end

  context 'when container does not exist' do
    it { has_container?('_no_such_container').should be_false }
  end
end


describe MyDockerRake::Utilities, '#has_image?' do
  include_context 'build_image'

  context 'when image exists' do
    it { has_image?(image).should be_true }
  end

  context 'when image does not exist' do
    before { remove_image(image, SILENCE_OPTIONS) }
    it { has_image?(image).should be_false }
  end

  context 'when nil passed' do
    it { has_image?(nil).should be_false }
  end

  context 'when empty string passed' do
    it { has_image?('').should be_false }
  end
end


describe MyDockerRake::Utilities, '#kill_container' do
  include_context 'run_container'

  context 'when container is running' do
    it 'kill container' do
      running_container?(container).should be_true
      kill_container(container, SILENCE_OPTIONS)
      running_container?(container).should be_false
    end
  end

  context 'when container is not running' do
    it 'do nothing' do
      proc {
        kill_container(container, SILENCE_OPTIONS)
      }.should_not raise_error
    end
  end
end


describe MyDockerRake::Utilities, '#remove_container' do
  include_context 'run_container'

  context 'when container is running' do
    it 'raise error' do
      proc {
        remove_container(container, SILENCE_OPTIONS)
      }.should raise_error(RuntimeError)
    end
  end

  context 'when container exists' do
    before { kill_container(container, SILENCE_OPTIONS) }

    it 'remove container' do
      proc {
        remove_container(container, SILENCE_OPTIONS)
      }.should_not raise_error

      has_container?(container).should be_false
    end
  end

  context 'when container does not exist' do
    it 'do nothing' do
      proc {
        kill_container(container, SILENCE_OPTIONS)
      }.should_not raise_error
    end
  end
end


describe MyDockerRake::Utilities, '#destroy_container' do
  include_context 'run_container'

  context 'when container is running' do
    it 'kill and remove container' do
      proc {
        destroy_container(container, SILENCE_OPTIONS)
      }.should_not raise_error

      running_container?(container).should be_false
      has_container?(container).should be_false
    end
  end

  context 'when container exists' do
    before { kill_container(container, SILENCE_OPTIONS) }

    it 'remove container' do
      proc {
        destroy_container(container, SILENCE_OPTIONS)
      }.should_not raise_error

      has_container?(container).should be_false
    end
  end

  context 'when container does not exist' do
    it 'do nothing' do
      proc {
        destroy_container(container, SILENCE_OPTIONS)
      }.should_not raise_error
    end
  end
end


describe MyDockerRake::Utilities, '#remove_image' do
  include_context 'build_image'

  context 'when image exists' do
    it {
      remove_image(image, SILENCE_OPTIONS)
      has_image?(image).should be_false
    }
  end

  context 'when image does not exist' do
    before { system "docker rmi #{image} >/dev/null 2>&1" }

    it 'do nothing' do
      proc {
        remove_image(image, SILENCE_OPTIONS)
      }.should_not raise_error
    end
  end
end


describe MyDockerRake::Utilities, '#get_projects' do
  let (:projects) { ['project_a', 'project_b', 'project_c/tag1', 'project_c/tag2'] }
  let (:tmpdir)   { Dir.mktmpdir }

  context 'when has multiple projects' do
    around(:each) { |example|
      projects.each do |project|
        project_dir = File.join(tmpdir, project)
        FileUtils.mkdir_p(project_dir)
        FileUtils.touch(File.join(project_dir, 'Dockerfile'))
      end
      example.run
      FileUtils.remove_dir(tmpdir)
    }

    it {
      get_projects(tmpdir).should == projects
    }
  end

  context 'when has no projects' do
    let (:tmpdir) { Dir.mktmpdir }
    after(:each)  { |example|
      FileUtils.remove_dir(tmpdir)
    }

    it {
      get_projects(tmpdir).should be_empty
    }
  end

  context 'when root directory does not exist' do
    let (:tmpdir) { Dir.mktmpdir }
    before(:each) { |example|
      FileUtils.remove_dir(tmpdir)
    }

    it {
      proc { get_projects(tmpdir) }.should raise_error(Errno::ENOENT)
    }
  end
end
