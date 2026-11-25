package com.google.ai.edge.gallery.customtasks.invoiceextraction

import android.content.Context
import android.util.Log
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Receipt
import androidx.compose.runtime.Composable
import com.google.ai.edge.gallery.customtasks.common.CustomTask
import com.google.ai.edge.gallery.customtasks.common.CustomTaskData
import com.google.ai.edge.gallery.data.Category
import com.google.ai.edge.gallery.data.ConfigKeys
import com.google.ai.edge.gallery.data.Model
import com.google.ai.edge.gallery.data.Task
import com.google.ai.edge.gallery.ui.llmchat.LlmChatModelHelper
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dagger.multibindings.IntoSet
import javax.inject.Inject
import kotlinx.coroutines.CoroutineScope

private const val TAG = "InvoiceExtractionTask"

const val TASK_ID_INVOICE_EXTRACTION = "invoice_extraction"

class InvoiceExtractionTask @Inject constructor() : CustomTask {

  override val task: Task = Task(
    id = TASK_ID_INVOICE_EXTRACTION,
    label = "Whisper to Invoice",
    category = Category.LLM,
    icon = Icons.Outlined.Receipt,
    description = "Speak your sale in any language — Gemma 4 extracts it into a professional invoice, 100% offline.",
    shortDescription = "Voice → Invoice, offline",
    models = mutableListOf(),
    useThemeColor = true,
  )

  override fun initializeModelFn(
    context: Context,
    coroutineScope: CoroutineScope,
    model: Model,
    onDone: (String) -> Unit,
  ) {
    Log.i(
      TAG,
      "initializeModelFn: model='${model.name}' accelerator=" +
        "${model.getStringConfigValue(key = ConfigKeys.ACCELERATOR, defaultValue = "unset")} " +
        "maxTokens=${model.getIntConfigValue(key = ConfigKeys.MAX_TOKENS, defaultValue = -1)}",
    )
    InvoiceDiagnostics.logMemory(context, "before-model-init")
    val initStartMs = System.currentTimeMillis()
    LlmChatModelHelper.initialize(
      context = context,
      model = model,
      supportImage = false,
      supportAudio = true,  // audio is the whole point
      onDone = { error ->
        Log.i(
          TAG,
          "initializeModelFn done in ${System.currentTimeMillis() - initStartMs}ms " +
            "error='${error}' instanceNull=${model.instance == null}",
        )
        InvoiceDiagnostics.logMemory(context, "after-model-init")
        onDone(error)
      },
    )
  }

  override fun cleanUpModelFn(
    context: Context,
    coroutineScope: CoroutineScope,
    model: Model,
    onDone: () -> Unit,
  ) {
    LlmChatModelHelper.cleanUp(model = model, onDone = onDone)
  }

  @Composable
  override fun MainScreen(data: Any) {
    val taskData = data as CustomTaskData
    InvoiceExtractionScreen(
      task = task,
      model = taskData.modelManagerViewModel.uiState.value.selectedModel,
      bottomPadding = taskData.bottomPadding,
    )
  }
}

@Module
@InstallIn(SingletonComponent::class)
internal object InvoiceExtractionTaskModule {
  @Provides
  @IntoSet
  fun provideTask(): CustomTask = InvoiceExtractionTask()
}
