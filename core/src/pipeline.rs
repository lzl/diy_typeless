#[derive(Debug, uniffi::Record)]
#[must_use]
pub struct PipelineResult {
    pub raw_text: String,
    pub polished_text: String,
}

