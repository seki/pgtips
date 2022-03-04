require 'aws-sdk-s3'

class Bucket
  def initialize
    credentials = Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_SECRET_ACCESS_KEY'])
    region = ENV['S3_REGION']
    Aws.config.update(
      region: region,
      credentials: credentials
    )
    @s3 = Aws::S3::Client.new
    @bucket = ENV['S3_BUCKET'] || "tea-log"
  end
  attr_reader :s3, :bucket

  def put_object(key, body)
    @s3.put_object(bucket: @bucket, key: key, body: body)
  end

  def get_object(key)
    @s3.get_object(bucket: @bucket, key: key)
  end

  def list_objects(prefix="")
    @s3.list_objects(bucket: @bucket, prefix: prefix)
  end

  def presigned(key)
    signer = Aws::S3::Presigner.new
    signer.presigned_url(
      :get_object, bucket: @bucket, key: key
    )
  end
end
