using System.IO;

namespace Fixtures.DuplexHighRisk
{
    public sealed class ArchiveTransferService : IArchiveTransfer
    {
        public Stream Download(string archiveId)
        {
            return new MemoryStream(new byte[] { 1, 2, 3, 4 });
        }

        public void Upload(Stream content)
        {
            using (var sink = new MemoryStream())
            {
                content.CopyTo(sink);
            }
        }
    }
}
