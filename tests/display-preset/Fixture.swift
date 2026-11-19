import Foundation
@main enum Test {
 static func main() throws {
  let a=DisplayPresetCopy.clock,b=DisplayPresetCopy.line
  func edit(_ s:String)throws->DisplayPresetCopy{try DisplayPresetCopy.review(Data(s.utf8))}
  let orig="""
  { "metadata":{"version":2,"note":"unchanged\\\"text"}, "tweaks": { "\(a)" : { "enabled" : true,"value":true }, "\(b)":{"enabled":true}, "other": {"enabled":true, "id":9999999999999999999,"items":[null,false,{"enabled":true}]} } }
  """
  let result=try edit(orig);precondition(result.changed==[a,b]);let expected=orig.replacingOccurrences(of:"\"enabled\" : true",with:"\"enabled\" : false").replacingOccurrences(of:"\"\(b)\":{\"enabled\":true",with:"\"\(b)\":{\"enabled\":false");precondition(result.data==Data(expected.utf8));let again=try DisplayPresetCopy.review(result.data);precondition(again.changed.isEmpty && again.data==result.data)
  for bad in ["{}",orig.replacingOccurrences(of:"\"version\":2",with:"\"version\":3"),orig.replacingOccurrences(of:"\"enabled\" : true",with:"\"enabled\":0"),orig.replacingOccurrences(of:"\"enabled\" : true",with:"\"enabled\":true,\"en\\u0061bled\":false"),orig+"garbage",String(repeating:" ",count:DisplayPresetCopy.limit+1)] {precondition((try? edit(bad))==nil)}
  let empty=try edit("{\"metadata\":{\"version\":2},\"tweaks\":{}}");precondition(empty.present.isEmpty && empty.changed.isEmpty);print("Display preset tests passed: targeted bytes, unrelated settings, repeat, limits, invalid and ambiguous files")
 }
}
