#[derive(Debug, uniffi::Record)]
pub struct PipelineResult {
    pub raw_text: String,
    pub polished_text: String,
}

