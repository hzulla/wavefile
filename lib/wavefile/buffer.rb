module WaveFile
  # Error that is raised when an attempt is made to perform an unsupported or undefined
  # conversion between two sample data formats.
  class BufferConversionError < StandardError; end


  # Represents a collection of samples in a certain format (e.g. 16-bit mono).
  # Reader returns sample data contained in Buffers, and Writer expects incoming sample
  # data to be contained in a Buffer as well.
  #
  # Contains methods to convert the sample data in the buffer to a different format.
  class Buffer

    # Creates a new Buffer. You are on the honor system to make sure that the given
    # sample data matches the given format.
    def initialize(samples, format)
      @samples = samples
      @format = format
    end


    # Creates a new Buffer containing the sample data of this Buffer, but converted to
    # a different format.
    #
    # new_format - The format that the sample data should be converted to
    #
    # Examples
    #
    #   new_format = Format.new(:mono, 16, 44100)
    #   new_buffer = old_buffer.convert(new_format)
    #
    # Returns a new Buffer; the existing Buffer is unmodified.
    def convert(new_format)
      new_samples = convert_buffer(@samples.dup, @format, new_format)
      return Buffer.new(new_samples, new_format)
    end


    # Converts the sample data contained in the Buffer to a new format. The sample data
    # is converted in place, so the existing Buffer is modified.
    #
    # new_format - The format that the sample data should be converted to
    #
    # Examples
    #
    #   new_format = Format.new(:mono, 16, 44100)
    #   old_buffer.convert!(new_format)
    #
    # Returns self.
    def convert!(new_format)
      @samples = convert_buffer(@samples, @format, new_format)
      @format = new_format
      return self
    end


    # The number of channels the buffer's sample data has
    def channels
      return @format.channels
    end


    # The bits per sample of the buffer's sample data
    def bits_per_sample
      return @format.bits_per_sample
    end


    # The sample rate of the buffer's sample data
    def sample_rate
      return @format.sample_rate
    end

    attr_reader :samples

  private

    def convert_buffer(samples, old_format, new_format)
      unless old_format.channels == new_format.channels
        samples = convert_buffer_channels(samples, old_format.channels, new_format.channels)
      end

      unless old_format.bits_per_sample == new_format.bits_per_sample
        samples = convert_buffer_bits_per_sample(samples, old_format.bits_per_sample, new_format.bits_per_sample)
      end

      return samples
    end

    def convert_buffer_channels(samples, old_channels, new_channels)
      # The cases of mono -> stereo and vice-versa are handled specially,
      # because those conversion methods are faster than the general methods,
      # and the large majority of wave files are expected to be either mono or stereo.
      if old_channels == 1 && new_channels == 2
        samples.map! {|sample| [sample, sample]}
      elsif old_channels == 2 && new_channels == 1
        samples.map! {|sample| (sample[0] + sample[1]) / 2}
      elsif old_channels == 1 && new_channels >= 2
        samples.map! {|sample| [].fill(sample, 0, new_channels)}
      elsif old_channels >= 2 && new_channels == 1
        samples.map! {|sample| sample.inject(0) {|sub_sample, sum| sum + sub_sample } / old_channels }
      elsif old_channels > 2 && new_channels == 2
        samples.map! {|sample| [sample[0], sample[1]]}
      else
        raise BufferConversionError,
              "Conversion of sample data from #{old_channels} channels to #{new_channels} channels is unsupported"
      end

      return samples
    end

    def convert_buffer_bits_per_sample(samples, old_bits_per_sample, new_bits_per_sample)
      shift_amount = (new_bits_per_sample - old_bits_per_sample).abs
      more_than_one_channel = (Array === samples.first)

      if old_bits_per_sample == 8
        if more_than_one_channel
          samples.map! do |sample|
            sample.map! {|sub_sample| (sub_sample - 128) << shift_amount }
          end
        else
          samples.map! {|sample| (sample - 128) << shift_amount }
        end
      elsif new_bits_per_sample == 8
        if more_than_one_channel
          samples.map! do |sample|
            sample.map! {|sub_sample| (sub_sample >> shift_amount) + 128 }
          end
        else
          samples.map! {|sample| (sample >> shift_amount) + 128 }
        end
      else
        operator = (new_bits_per_sample > old_bits_per_sample) ? :<< : :>>

        if more_than_one_channel
          samples.map! do |sample|
            sample.map! {|sub_sample| sub_sample.send(operator, shift_amount) }
          end
        else
          samples.map! {|sample| sample.send(operator, shift_amount) }
        end
      end

      return samples
    end
  end
end
