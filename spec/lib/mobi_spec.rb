require 'spec_helper'
require 'pry-byebug'

require 'mobi'

describe Mobi do
  it "instantiates a Mobi::Metadata object" do
    file = File.open('spec/fixtures/sherlock.mobi')
    meta = Mobi.metadata(file)
    expect(meta).to be_an_instance_of(Mobi::Metadata)
    file2 = File.open('spec/fixtures/Eloquent_JavaScript.mobi')
    meta2 = Mobi.metadata(file2)
    meta.save_cover_image('sherlock.jpg')
    meta2.save_cover_image('Eloquent_Script.jpg')
  end
end
